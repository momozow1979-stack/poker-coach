//! `EquityCache`: a compact native replacement for `PostflopSubgame`'s
//! `_equity_cache: dict[tuple[Combo, Combo, tuple[int, ...]], float]`
//! (`cfr_solver/games/postflop_subgame.py`'s `_equity`).
//!
//! ## Why this exists (measured, not assumed)
//!
//! `BENCHMARKS.md`'s Stage S2 full-hand-range measurement flagged the
//! equity cache as holding "27-34% as many entries as information sets" and
//! "a non-negligible contributor already folded into the RSS figures" but
//! did not isolate its own per-entry cost. Direct measurement (same
//! methodology already used for `_index` in `node_index.rs`:
//! `resource.getrusage(...).ru_maxrss` before/after inserting 2,000,000
//! entries fresh into a plain `dict` keyed the same way this cache really
//! is keyed) found **~347 bytes/entry** — worse than the ~192 B/entry the
//! original `dict[str, int]` `_index` cost before `NodeIndex` replaced it.
//! The reason is the same disease in a more extreme form: every key is a
//! 3-tuple of tuples (`((u8,u8), (u8,u8), (u8,...,u8))`), so CPython pays
//! for four separate heap-allocated tuple objects (the outer 3-tuple plus
//! the two combo 2-tuples plus the board tuple) per cache entry, on top of
//! the dict's own per-entry bookkeeping.
//!
//! At the full ~92.2M-information-set target, with the equity cache holding
//! 27-34% as many entries, this alone was projected to cost roughly
//! 8.6-10.9GB -- likely the single largest contributor to Stage S4's
//! measured physical ceiling (~71.6-71.8M information sets, short of the
//! 92.2M target).
//!
//! ## Design
//!
//! Two things make this cache far more compressible than `NodeIndex` was:
//!
//! 1. **The key is always fixed-size and fixed-shape** -- unlike an
//!    arbitrary information-set string, there is no need for a length
//!    prefix or a `KEY_CAPACITY` margin. A `_equity()` call always passes a
//!    `(hero_combo, villain_combo, board)` where both combos are exactly 2
//!    cards and, in every path that actually reaches `_equity()` (i.e. past
//!    the river with no fold), `board` is exactly 5 cards -- verified by
//!    reading `PostflopSubgame.returns()`: every branch that could still
//!    have a board shorter than 5 returns earlier via
//!    `_payoffs_from_fold`. A `board_len` byte is still stored (rather than
//!    hardcoding 5) purely so a future caller with a different showdown
//!    board length doesn't silently corrupt an unrelated entry -- the same
//!    defensive posture `NodeIndex::encode` takes for `KEY_CAPACITY`.
//! 2. **The value is not an arbitrary float** -- `_equity` only ever
//!    returns exactly one of three constants (`0.0`, `0.5`, `1.0`), decided
//!    by comparing two hand ranks. So the cached payload is a single `u8`
//!    tag, not an 8-byte `f64`.
//!
//! This reuses `NodeIndex`'s proven chunked-arena design (see
//! `node_index.rs`'s module docstring for why a plain
//! `HashMap<RawKey, _>` measured *worse* than the dict it replaced: every
//! resize must copy every live entry's full key). The identity key here
//! (10 bytes: 1 board-length byte + 5 board bytes, zero-padded + 2 hero +
//! 2 villain) is much smaller than `NodeIndex`'s (up to 41 bytes), but at
//! tens of millions of entries a plain `Vec<RawKey>`'s resize-copy
//! transient is still worth avoiding, so the same chunked arena is reused
//! here rather than re-deriving a "is this key small enough to not
//! matter" judgment call.
//!
//! Unlike `NodeIndex`, this cache never needs to reconstruct an original
//! Python key (there is no `items()`/`average_strategy()`-style caller) and
//! is never persisted by `CFRSolver.save()`/`load()` -- `cfr.py`'s own
//! module docstring already establishes that `self.game` (and so this
//! cache) is deliberately NOT saved; `load()` takes a freshly-built `Game`
//! instance and lets caches like this one repopulate lazily during
//! resumed training. So there is no `packed_keys`/`load_packed_keys`
//! counterpart here -- this cache's public surface is a single method,
//! `equity()`, that looks up-or-computes-and-caches in one call, entirely
//! inside Rust (using `cards::evaluate_best_hand`, already ported and
//! exhaustively verified in Stage 8R-2) so a cache HIT never crosses the
//! FFI boundary more than once either.

use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;
use pyo3::types::PyBytes;
use std::collections::HashMap;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use crate::cards::evaluate_best_hand;

/// Longest board `_equity` is ever called with in this package's games
/// (see module docstring: always exactly 5 in every reachable
/// `PostflopSubgame` showdown path), plus defensive margin matching
/// `NodeIndex::KEY_CAPACITY`'s posture: a pathological caller passing a
/// longer board gets a clear error, never silent truncation/corruption.
const BOARD_CAPACITY: usize = 7;

/// `[0]` = board length, `[1..1+BOARD_CAPACITY]` = board cards
/// (zero-padded), `[1+BOARD_CAPACITY]`/`[+1]` = hero combo's two cards,
/// next two = villain combo's two cards. Fixed-size, so (unlike
/// `NodeIndex::RawKey`) no separate length-prefix decoding is needed for
/// the combo fields -- they're always exactly 2 cards each.
const KEY_LEN: usize = 1 + BOARD_CAPACITY + 2 + 2;
type RawKey = [u8; KEY_LEN];

fn encode(
    hero_combo: (u8, u8),
    villain_combo: (u8, u8),
    board: &[u8],
) -> PyResult<RawKey> {
    if board.len() > BOARD_CAPACITY {
        return Err(PyValueError::new_err(format!(
            "EquityCache: board has {} cards, exceeding fixed capacity of {} \
             (board={board:?}) -- widen BOARD_CAPACITY in native/src/equity_cache.rs \
             for a game whose showdown board is legitimately longer",
            board.len(),
            BOARD_CAPACITY,
        )));
    }
    let mut raw: RawKey = [0u8; KEY_LEN];
    raw[0] = board.len() as u8;
    raw[1..1 + board.len()].copy_from_slice(board);
    raw[1 + BOARD_CAPACITY] = hero_combo.0;
    raw[1 + BOARD_CAPACITY + 1] = hero_combo.1;
    raw[1 + BOARD_CAPACITY + 2] = villain_combo.0;
    raw[1 + BOARD_CAPACITY + 3] = villain_combo.1;
    Ok(raw)
}

fn hash_bytes(bytes: &[u8]) -> u64 {
    let mut h = DefaultHasher::new();
    bytes.hash(&mut h);
    h.finish()
}

/// `0` = hero loses (equity 0.0), `1` = tie (0.5), `2` = hero wins (1.0) --
/// see module docstring: `_equity`'s only three possible return values.
fn equity_code(hero_rank: u32, villain_rank: u32) -> u8 {
    match hero_rank.cmp(&villain_rank) {
        std::cmp::Ordering::Greater => 2,
        std::cmp::Ordering::Less => 0,
        std::cmp::Ordering::Equal => 1,
    }
}

fn code_to_equity(code: u8) -> f64 {
    match code {
        0 => 0.0,
        1 => 0.5,
        2 => 1.0,
        other => unreachable!("equity code must be 0, 1, or 2; got {other}"),
    }
}

/// Stable, append-only, chunked storage for encoded (key, value) pairs,
/// addressed directly by dense id -- same rationale as `node_index::Arena`:
/// growing this never moves or copies an already-written entry.
const CHUNK_LEN: usize = 65_536;

#[derive(Default)]
struct Arena {
    chunks: Vec<Box<[(RawKey, u8)]>>,
    len: usize,
}

impl Arena {
    fn push(&mut self, raw: RawKey, value: u8) -> u32 {
        let id = self.len;
        let chunk_idx = id / CHUNK_LEN;
        if chunk_idx == self.chunks.len() {
            self.chunks
                .push(vec![([0u8; KEY_LEN], 0u8); CHUNK_LEN].into_boxed_slice());
        }
        self.chunks[chunk_idx][id % CHUNK_LEN] = (raw, value);
        self.len += 1;
        id as u32
    }

    fn get(&self, id: u32) -> &(RawKey, u8) {
        let id = id as usize;
        &self.chunks[id / CHUNK_LEN][id % CHUNK_LEN]
    }

    fn len(&self) -> usize {
        self.len
    }
}

struct EquityCacheInner {
    arena: Arena,
    primary: HashMap<u64, u32>,
    overflow: Vec<(RawKey, u8, u32)>,
}

impl EquityCacheInner {
    fn new() -> Self {
        EquityCacheInner {
            arena: Arena::default(),
            primary: HashMap::new(),
            overflow: Vec::new(),
        }
    }

    /// Returns the cached equity code if `raw` is already present, without
    /// inserting anything -- factored out so unit tests can force
    /// collisions deterministically, matching `NodeIndexInner`'s pattern.
    fn get_impl(&self, raw: &RawKey, hash_fn: impl Fn(&[u8]) -> u64) -> Option<u8> {
        let h = hash_fn(raw);
        if let Some(&id) = self.primary.get(&h) {
            let (candidate_raw, value) = self.arena.get(id);
            if candidate_raw == raw {
                return Some(*value);
            }
            for &(candidate_raw, value, _id) in &self.overflow {
                if &candidate_raw == raw {
                    return Some(value);
                }
            }
        }
        None
    }

    fn insert_impl(&mut self, raw: RawKey, value: u8, hash_fn: impl Fn(&[u8]) -> u64) {
        let h = hash_fn(&raw);
        if let Some(&id) = self.primary.get(&h) {
            // Same hash, different key already stored under it: a genuine
            // collision. Verified byte comparison already happened in
            // `get_impl` before this is ever called for a cache miss on an
            // existing hash bucket, so this insert always represents a new
            // key -- push it to the arena and record it in `overflow` so
            // future lookups for THIS key find it via the verified-byte-
            // compare path, never by trusting the hash alone.
            let _ = id;
            let new_id = self.arena.push(raw, value);
            self.overflow.push((raw, value, new_id));
            return;
        }
        let id = self.arena.push(raw, value);
        self.primary.insert(h, id);
    }

    fn len(&self) -> usize {
        self.arena.len()
    }
}

/// Native replacement for `PostflopSubgame._equity_cache`. See module
/// docstring for why and for the design this settled on.
///
/// `module = "cfr_solver._native"` is required (not cosmetic) for pickling
/// to work at all: pickle locates a class to reconstruct via
/// `obj.__class__.__module__` + `__qualname__`, and a PyO3 class without an
/// explicit `module` defaults to `__module__ == "builtins"`, where
/// `EquityCache` doesn't exist -- confirmed directly (`pickle.dumps` failed
/// with `PicklingError: attribute lookup EquityCache on builtins failed`
/// before this was added).
#[pyclass(module = "cfr_solver._native")]
pub struct EquityCache {
    inner: EquityCacheInner,
}

#[pymethods]
impl EquityCache {
    #[new]
    fn new() -> Self {
        EquityCache { inner: EquityCacheInner::new() }
    }

    /// Look up (hero_combo, villain_combo, board)'s cached equity, computing
    /// and caching it via `cards::evaluate_best_hand` on a miss. Matches
    /// `PostflopSubgame._equity`'s exact semantics: `1.0` if hero's best
    /// hand outranks villain's, `0.0` if villain's outranks hero's, `0.5`
    /// on a tie.
    fn equity(
        &mut self,
        hero_combo: (u8, u8),
        villain_combo: (u8, u8),
        board: Vec<u8>,
    ) -> PyResult<f64> {
        let raw = encode(hero_combo, villain_combo, &board)?;
        if let Some(code) = self.inner.get_impl(&raw, hash_bytes) {
            return Ok(code_to_equity(code));
        }

        let mut hero_cards = Vec::with_capacity(2 + board.len());
        hero_cards.push(hero_combo.0);
        hero_cards.push(hero_combo.1);
        hero_cards.extend_from_slice(&board);
        let mut villain_cards = Vec::with_capacity(2 + board.len());
        villain_cards.push(villain_combo.0);
        villain_cards.push(villain_combo.1);
        villain_cards.extend_from_slice(&board);

        let hero_rank = evaluate_best_hand(&hero_cards);
        let villain_rank = evaluate_best_hand(&villain_cards);
        let code = equity_code(hero_rank, villain_rank);
        self.inner.insert_impl(raw, code, hash_bytes);
        Ok(code_to_equity(code))
    }

    fn __len__(&self) -> usize {
        self.inner.len()
    }

    /// Pickle support. `PostflopSubgame` (which holds one of these as
    /// `_equity_cache`) is pickled whenever `exploitability.py`'s Stage 7
    /// `ProcessPoolExecutor`-based parallel path sends `game` to worker
    /// processes via `initargs` -- a plain `dict`-backed cache round-tripped
    /// through pickle for free; a `#[pyclass]` does not, by default, so this
    /// is required for `PostflopSubgame` to stay picklable at all, not an
    /// optional nicety. Serializes every `(key, value)` pair as one
    /// fixed-size `KEY_LEN + 1`-byte record (no length prefix needed, unlike
    /// `NodeIndex::packed_keys` -- every record here is the same size),
    /// concatenated, so the cache's contents (not just its existence)
    /// survive the round trip exactly, matching what pickling a `dict`
    /// already did before this replaced it.
    fn __getstate__<'py>(&self, py: Python<'py>) -> PyResult<Bound<'py, PyBytes>> {
        let n = self.inner.len();
        let record_len = KEY_LEN + 1;
        PyBytes::new_bound_with(py, n * record_len, |out| {
            for id in 0..n as u32 {
                let (raw, value) = self.inner.arena.get(id);
                let start = (id as usize) * record_len;
                out[start..start + KEY_LEN].copy_from_slice(raw);
                out[start + KEY_LEN] = *value;
            }
            Ok(())
        })
    }

    fn __setstate__(&mut self, state: &Bound<'_, PyBytes>) -> PyResult<()> {
        let bytes = state.as_bytes();
        let record_len = KEY_LEN + 1;
        if bytes.len() % record_len != 0 {
            return Err(PyValueError::new_err(format!(
                "EquityCache.__setstate__: blob length {} is not a multiple of \
                 the fixed record size {record_len} -- corrupt pickle data",
                bytes.len(),
            )));
        }
        let mut inner = EquityCacheInner::new();
        let mut offset = 0usize;
        while offset < bytes.len() {
            let mut raw: RawKey = [0u8; KEY_LEN];
            raw.copy_from_slice(&bytes[offset..offset + KEY_LEN]);
            let value = bytes[offset + KEY_LEN];
            inner.insert_impl(raw, value, hash_bytes);
            offset += record_len;
        }
        self.inner = inner;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cache() -> EquityCacheInner {
        EquityCacheInner::new()
    }

    #[test]
    fn get_impl_returns_none_before_any_insert() {
        let c = cache();
        let raw = encode((0, 1), (2, 3), &[4, 5, 6, 7, 8]).unwrap();
        assert_eq!(c.get_impl(&raw, hash_bytes), None);
    }

    #[test]
    fn insert_then_get_round_trips() {
        let mut c = cache();
        let raw = encode((0, 1), (2, 3), &[4, 5, 6, 7, 8]).unwrap();
        c.insert_impl(raw, 2, hash_bytes);
        assert_eq!(c.get_impl(&raw, hash_bytes), Some(2));
        assert_eq!(c.len(), 1);
    }

    #[test]
    fn distinct_keys_stay_distinct() {
        let mut c = cache();
        let raw_a = encode((0, 1), (2, 3), &[4, 5, 6, 7, 8]).unwrap();
        let raw_b = encode((0, 1), (2, 3), &[4, 5, 6, 7, 9]).unwrap();
        c.insert_impl(raw_a, 0, hash_bytes);
        c.insert_impl(raw_b, 2, hash_bytes);
        assert_eq!(c.get_impl(&raw_a, hash_bytes), Some(0));
        assert_eq!(c.get_impl(&raw_b, hash_bytes), Some(2));
        assert_eq!(c.len(), 2);
    }

    /// A degenerate "hash function" mapping every key to the same bucket --
    /// see `node_index.rs`'s identical test for why this is how the
    /// overflow/collision-safety path gets exercised without needing an
    /// astronomically large number of real keys.
    fn always_collide(_bytes: &[u8]) -> u64 {
        0
    }

    #[test]
    fn distinct_keys_stay_distinct_even_under_total_hash_collision() {
        let mut c = cache();
        let keys: Vec<RawKey> = (0u8..5)
            .map(|i| encode((0, 1), (2, 3), &[4, 5, 6, 7, i]).unwrap())
            .collect();
        for (i, &raw) in keys.iter().enumerate() {
            assert_eq!(c.get_impl(&raw, always_collide), None);
            c.insert_impl(raw, i as u8, always_collide);
        }
        for (i, &raw) in keys.iter().enumerate() {
            assert_eq!(c.get_impl(&raw, always_collide), Some(i as u8));
        }
        assert_eq!(c.len(), keys.len());
    }

    #[test]
    fn board_longer_than_capacity_is_rejected_clearly() {
        let board = vec![0u8; BOARD_CAPACITY + 1];
        assert!(encode((0, 1), (2, 3), &board).is_err());
    }

    #[test]
    fn arena_chunk_boundary_is_handled_correctly() {
        let mut c = cache();
        let n = CHUNK_LEN + 10;
        let mut keys = Vec::with_capacity(n);
        for i in 0..n {
            let board = [
                (i & 0xff) as u8,
                ((i >> 8) & 0xff) as u8,
                ((i >> 16) & 0xff) as u8,
                0,
                1,
            ];
            let raw = encode((0, 1), (2, 3), &board).unwrap();
            c.insert_impl(raw, (i % 3) as u8, hash_bytes);
            keys.push((raw, (i % 3) as u8));
        }
        for (raw, expected) in keys {
            assert_eq!(c.get_impl(&raw, hash_bytes), Some(expected));
        }
        assert_eq!(c.len(), n);
    }

    #[test]
    fn equity_code_round_trips_all_three_values() {
        assert_eq!(code_to_equity(equity_code(5, 3)), 1.0);
        assert_eq!(code_to_equity(equity_code(3, 5)), 0.0);
        assert_eq!(code_to_equity(equity_code(4, 4)), 0.5);
    }
}
