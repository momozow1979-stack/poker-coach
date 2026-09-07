//! Rust-side `avg_strategy` representation (Stage 8R-4). Python threads
//! `avg_strategy: dict[str, dict[Action, float]]` through every call of
//! `exploitability.py`'s walk; the whole point of this module is to convert
//! that Python dict into a Rust hashmap exactly ONCE per top-level API call
//! (`exploitability`/`best_response_value`/`actual_value`/
//! `exploitability_per_player` in `lib.rs`), not once per combo pair or once
//! per policy-iteration sweep -- see this module's docs and `lib.rs` for
//! where that single conversion happens.
//!
//! The action alphabet in this game is exactly `{'x','b','c','f'}` (checked
//! against `rules.rs`'s `legal_for_tokens`, which only ever emits bytes from
//! that set) -- never all four legal at the same history (it's either
//! `{x,b}`, `{f,c,b}`, or `{f,c}`), so a fixed 4-slot array indexed by
//! `action_index` below is enough to hold a full per-action-probability (or
//! per-action-accumulator) row without a nested hash map. This indexing
//! convention is purely internal to the Rust side -- no Python code ever
//! observes it (the FFI boundary only ever crosses plain action characters
//! as `String`s, going through `rules::next_history`, never these indices).

use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;
use pyo3::types::PyDict;
use rustc_hash::FxHashMap;

/// Maps one of the four legal action bytes to a fixed slot 0..4. Panics on
/// any other byte -- every caller in this crate only ever passes bytes that
/// came from `rules::legal_for_tokens`, so an unrecognized byte here means a
/// bug upstream, not a reachable game state.
#[inline]
pub fn action_index(action: u8) -> usize {
    match action {
        b'x' => 0,
        b'b' => 1,
        b'c' => 2,
        b'f' => 3,
        other => panic!(
            "action byte {:?} is not in the poker action alphabet x/b/c/f",
            other as char
        ),
    }
}

/// The trained average strategy, converted once from the Python
/// `dict[str, dict[Action, float]]` into a native hash map keyed by the same
/// information-set-key strings `rules::information_set_key` produces.
pub struct AvgStrategy(FxHashMap<Box<str>, [f64; 4]>);

impl AvgStrategy {
    /// Iterates the Python `dict[str, dict[str, float]]` exactly once,
    /// building the native map. Does NOT renormalize -- exactly like
    /// Python's `_strategy_at`, a present entry is trusted as-is to already
    /// be a valid probability distribution over that information set's
    /// legal actions.
    pub fn from_py_dict(dict: &Bound<'_, PyDict>) -> PyResult<Self> {
        let mut map: FxHashMap<Box<str>, [f64; 4]> = FxHashMap::default();
        map.reserve(dict.len());
        for (key_obj, val_obj) in dict.iter() {
            let key: String = key_obj.extract()?;
            let inner = val_obj.downcast::<PyDict>().map_err(|_| {
                PyValueError::new_err(format!(
                    "avg_strategy[{key:?}] must be a dict[str, float]"
                ))
            })?;
            let mut row = [0.0f64; 4];
            for (action_obj, prob_obj) in inner.iter() {
                let action: String = action_obj.extract()?;
                let bytes = action.as_bytes();
                if bytes.len() != 1 {
                    return Err(PyValueError::new_err(format!(
                        "avg_strategy[{key:?}] has non-single-character action key {action:?}"
                    )));
                }
                let prob: f64 = prob_obj.extract()?;
                row[action_index(bytes[0])] = prob;
            }
            map.insert(key.into_boxed_str(), row);
        }
        Ok(AvgStrategy(map))
    }

    /// Mirrors `_strategy_at`'s exact fallback semantics: if `key` is present
    /// in the trained strategy, its (trusted, un-renormalized) row is
    /// returned; otherwise a uniform distribution over `actions` is
    /// returned (slots for actions not in `actions` are left at 0.0, which
    /// is fine since every caller only ever reads slots for `actions`).
    pub fn strategy_at(&self, key: &str, actions: &[u8]) -> [f64; 4] {
        match self.0.get(key) {
            Some(row) => *row,
            None => {
                let mut row = [0.0f64; 4];
                let p = 1.0 / actions.len() as f64;
                for &a in actions {
                    row[action_index(a)] = p;
                }
                row
            }
        }
    }

    #[cfg(test)]
    pub fn from_entries(entries: impl IntoIterator<Item = (&'static str, [f64; 4])>) -> Self {
        let mut map = FxHashMap::default();
        for (k, v) in entries {
            map.insert(k.to_string().into_boxed_str(), v);
        }
        AvgStrategy(map)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strategy_at_returns_the_stored_row_when_the_key_is_present() {
        let mut row = [0.0f64; 4];
        row[action_index(b'x')] = 0.3;
        row[action_index(b'b')] = 0.7;
        let strat = AvgStrategy::from_entries([("k1", row)]);
        let got = strat.strategy_at("k1", &[b'x', b'b']);
        assert_eq!(got[action_index(b'x')], 0.3);
        assert_eq!(got[action_index(b'b')], 0.7);
    }

    #[test]
    fn strategy_at_falls_back_to_uniform_when_the_key_is_missing() {
        let strat = AvgStrategy::from_entries([]);
        let got = strat.strategy_at("missing", &[b'f', b'c', b'b']);
        assert_eq!(got[action_index(b'f')], 1.0 / 3.0);
        assert_eq!(got[action_index(b'c')], 1.0 / 3.0);
        assert_eq!(got[action_index(b'b')], 1.0 / 3.0);
    }

    #[test]
    fn strategy_at_does_not_renormalize_a_present_but_unnormalized_row() {
        // Not something Python's `_strategy_at` would ever be handed in
        // practice (a trained `average_strategy()` always sums to 1), but
        // the port must not silently "fix" whatever it is handed -- Python
        // doesn't renormalize here, so neither should Rust.
        let mut row = [0.0f64; 4];
        row[action_index(b'x')] = 0.9;
        row[action_index(b'b')] = 0.9;
        let strat = AvgStrategy::from_entries([("k1", row)]);
        let got = strat.strategy_at("k1", &[b'x', b'b']);
        assert_eq!(got[action_index(b'x')], 0.9);
        assert_eq!(got[action_index(b'b')], 0.9);
    }

    #[test]
    fn action_index_is_a_bijection_over_the_four_action_bytes() {
        let idxs: Vec<usize> = [b'x', b'b', b'c', b'f'].iter().map(|&a| action_index(a)).collect();
        let mut sorted = idxs.clone();
        sorted.sort_unstable();
        assert_eq!(sorted, vec![0, 1, 2, 3]);
    }
}
