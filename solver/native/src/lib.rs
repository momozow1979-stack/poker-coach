//! Stage 8R-1 scaffolded a single no-op `ping()` function so the Python <->
//! Rust build pipeline (maturin, PyO3, CI) could be proven end-to-end before
//! any real logic was ported. `ping()` is untouched below — this module now
//! also carries `NodeIndex`, a completely separate, narrowly-scoped native
//! replacement for `CFRSolver._index: dict[str, int]` in `cfr.py` (see that
//! module's docstring and `BENCHMARKS.md`'s "情報集合の保存方式" section for
//! why: a pure-Python `dict[str, int]` costs ~147 bytes/entry, dominated by
//! CPython's per-entry dict bookkeeping plus a separately heap-allocated
//! `str` object per key — a floor a prior pure-Python optimization pass
//! already hit and could not get under).
//!
//! ## Design, including a real dead end that measurement caught
//!
//! Every information-set key this package's games produce (`kuhn.py`,
//! `kuhn3p.py`, `leduc.py`, `flop_subgame.py`, `postflop_subgame.py`) is
//! built from a small, bounded character set (digits, `|`, `:`, and a
//! handful of action letters) with a bounded length — `postflop_subgame.py`
//! is the longest: 2-digit-per-card own-combo (4 chars) + up to 5 board
//! cards (10 chars) + 3 `|` separators + 3 action-history fields, each
//! bounded by `max_wagers_per_round` (tested up to 3 in this codebase,
//! giving `max_wagers + 2` = 5 chars/round, 15 total) — 32 characters in the
//! worst case actually exercised by this package's tests. `KEY_CAPACITY`
//! below is set above that with real margin.
//!
//! The first design tried here was the obvious one: a single
//! `HashMap<RawKey, u32>`, keying directly on a fixed-size inline byte
//! array. It measured *worse* than the plain Python `dict[str, int]` it was
//! meant to replace (~260-280 B/entry vs. ~192 B/entry, both measured the
//! same way — `resource.getrusage(...).ru_maxrss` before/after inserting
//! 2,000,000 entries fresh, matching `BENCHMARKS.md`'s own methodology).
//! The reason, verified by direct instrumentation (`HashMap::capacity()` at
//! specific counts): `HashMap`/`hashbrown` grows its backing table by
//! doubling, and because `RawKey` is ~40-50 bytes, every resize must
//! *physically copy every live entry's full key bytes* into the new,
//! larger backing array — while the *old* array is still briefly alive.
//! That transient (old + new tables coexisting mid-resize) is captured
//! forever by `ru_maxrss` (a running peak, never decreasing), and scales
//! with `KEY_CAPACITY`. Plain CPython `dict`, by contrast, only ever
//! resizes a small internal index/hash table on growth — the actual `str`
//! *objects* are heap-allocated once and never moved, so its resize
//! transient stays cheap regardless of key length. Inlining the key
//! (deliberately avoiding a separate per-entry allocation, per the original
//! design brief) traded that per-entry heap allocation for a resize-time
//! copy cost proportional to key size — a real, measured regression, not a
//! hypothetical one, and worth recording here so a future change doesn't
//! reintroduce it by going back to a single flat `HashMap<RawKey, _>`.
//!
//! The fix keeps the "no per-entry heap allocation" property while
//! decoupling the *small, frequently-resized* lookup structure from the
//! *large, stable* key storage — the same separation CPython's own dict
//! already gets "for free" from having key objects live outside the table:
//!
//! - `Arena`: key bytes live in fixed-size chunks (`CHUNK_LEN` entries
//!   each), addressed directly by (dense, insertion-order) node id. A new
//!   chunk is one `Vec` allocation; existing chunks are *never moved or
//!   copied* once written — so growing the arena costs one allocation per
//!   `CHUNK_LEN` entries, not a copy of everything already stored.
//! - `primary: HashMap<u64, u32>` maps a key's 64-bit hash to its id. This
//!   table is what actually resizes on growth, and each slot is small
//!   (hash + id, ~13 bytes) regardless of how long keys are — so the
//!   resize-transient cost this time stays small too.
//! - `overflow: Vec<(RawKey, u32)>` — a genuine 64-bit hash collision
//!   between two *different* keys is astronomically unlikely at this
//!   package's scale (~92M entries), but "unlikely" is not a correctness
//!   argument this codebase accepts (see its own "no unverified
//!   approximation" principle): every lookup verifies the *actual* key
//!   bytes (via the arena) before trusting a hash match, and a genuine
//!   collision falls back to this small linear-scanned list instead of
//!   silently aliasing two different information sets onto the same id.
//!   In ordinary operation this list stays empty.
//!
//! `average_strategy()` (in `cfr.py`) is the only caller of `items()`, and
//! it only runs once, after training — so reconstructing an owned `String`
//! per entry there is fine; it's `get_or_create()` (the hot training-loop
//! path) that must never allocate per call (beyond the occasional new
//! arena chunk / index resize), and it doesn't.

use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;
use std::collections::HashMap;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

/// Trivial no-op used to verify the native extension loads and runs.
#[pyfunction]
fn ping() -> i64 {
    42
}

/// Longest information-set key this package's games are ever exercised with
/// (see module docstring), plus real margin. Not a hard theoretical bound —
/// a pathological caller-supplied `max_wagers_per_round` could in principle
/// exceed it — which is exactly why `get_or_create` returns a clear
/// `PyValueError` instead of silently truncating when a key doesn't fit.
const KEY_CAPACITY: usize = 40;

/// Entries per arena chunk. Each chunk is one `Vec` allocation of
/// `CHUNK_LEN * size_of::<RawKey>()` bytes (~1.7MB at `KEY_CAPACITY=40`);
/// large enough that per-chunk allocation overhead is negligible relative
/// to the tens of millions of entries this store is sized for, small enough
/// that a handful of chunks are never wastefully over-allocated for the
/// small games (Kuhn/Leduc) this same code path also serves.
const CHUNK_LEN: usize = 65_536;

/// `[0]` = key length in bytes (`key.len() <= KEY_CAPACITY` is enforced by
/// `encode`), `[1..]` = the key's bytes, zero-padded. A plain fixed-size
/// byte array so `derive`d `Eq`/`Hash`/`Copy` (bytewise) are correct and
/// free — no unsafe code.
type RawKey = [u8; KEY_CAPACITY + 1];

fn encode(key: &str) -> PyResult<RawKey> {
    let bytes = key.as_bytes();
    if bytes.len() > KEY_CAPACITY {
        return Err(PyValueError::new_err(format!(
            "information-set key is {} bytes, exceeding NodeIndex's fixed capacity of {} bytes \
             (key={key:?}) — widen KEY_CAPACITY in native/src/lib.rs for a game that legitimately \
             needs longer keys",
            bytes.len(),
            KEY_CAPACITY,
        )));
    }
    let mut raw: RawKey = [0u8; KEY_CAPACITY + 1];
    raw[0] = bytes.len() as u8;
    raw[1..1 + bytes.len()].copy_from_slice(bytes);
    Ok(raw)
}

fn decode(raw: &RawKey) -> String {
    let len = raw[0] as usize;
    String::from_utf8(raw[1..1 + len].to_vec())
        .expect("NodeIndex only ever stores bytes encoded from a valid Python str")
}

fn hash_bytes(bytes: &[u8]) -> u64 {
    let mut h = DefaultHasher::new();
    bytes.hash(&mut h);
    h.finish()
}

/// Stable, append-only, chunked storage for encoded keys, addressed
/// directly by dense node id. See module docstring: the whole point is
/// that growing this never moves or copies an already-written entry.
#[derive(Default)]
struct Arena {
    chunks: Vec<Box<[RawKey]>>,
    len: usize,
}

impl Arena {
    fn push(&mut self, raw: RawKey) -> u32 {
        let id = self.len;
        let chunk_idx = id / CHUNK_LEN;
        if chunk_idx == self.chunks.len() {
            self.chunks
                .push(vec![[0u8; KEY_CAPACITY + 1]; CHUNK_LEN].into_boxed_slice());
        }
        self.chunks[chunk_idx][id % CHUNK_LEN] = raw;
        self.len += 1;
        id as u32
    }

    fn get(&self, id: u32) -> &RawKey {
        let id = id as usize;
        &self.chunks[id / CHUNK_LEN][id % CHUNK_LEN]
    }

    fn len(&self) -> usize {
        self.len
    }
}

/// Core get-or-create logic, parameterized over the hash function so unit
/// tests below can force collisions deterministically (with a real
/// `SipHash`-quality hash, provoking an actual collision in a test would
/// mean generating on the order of 2^32 keys — not practical) and so verify
/// the `overflow` fallback actually runs and is actually correct, not just
/// unreachable code.
struct NodeIndexInner {
    arena: Arena,
    primary: HashMap<u64, u32>,
    overflow: Vec<(RawKey, u32)>,
}

impl NodeIndexInner {
    fn new() -> Self {
        NodeIndexInner {
            arena: Arena::default(),
            primary: HashMap::new(),
            overflow: Vec::new(),
        }
    }

    fn get_or_create_impl(
        &mut self,
        key: &str,
        hash_fn: impl Fn(&[u8]) -> u64,
    ) -> PyResult<(u32, bool)> {
        let raw = encode(key)?;
        let bytes = &raw[..1 + raw[0] as usize];
        let h = hash_fn(bytes);

        if let Some(&id) = self.primary.get(&h) {
            if *self.arena.get(id) == raw {
                return Ok((id, false));
            }
            // Same hash, different key: a genuine collision (or, under a
            // test's deliberately-degenerate hash_fn, an expected one).
            // Verified byte comparison — never trust the hash alone.
            for &(candidate_raw, candidate_id) in &self.overflow {
                if candidate_raw == raw {
                    return Ok((candidate_id, false));
                }
            }
            let id = self.arena.push(raw);
            self.overflow.push((raw, id));
            return Ok((id, true));
        }

        let id = self.arena.push(raw);
        self.primary.insert(h, id);
        Ok((id, true))
    }

    fn len(&self) -> usize {
        self.arena.len()
    }

    fn items(&self) -> Vec<(String, u32)> {
        (0..self.arena.len() as u32)
            .map(|id| (decode(self.arena.get(id)), id))
            .collect()
    }
}

/// Native replacement for `CFRSolver._index: dict[str, int]`. See module
/// docstring for why and for the design this settled on. Public surface is
/// deliberately tiny — `get_or_create` (hot path), `__len__` and `items`
/// (both only used outside the hot training loop) — mirroring exactly what
/// `cfr.py` needs and nothing more.
#[pyclass]
struct NodeIndex {
    inner: NodeIndexInner,
}

#[pymethods]
impl NodeIndex {
    #[new]
    fn new() -> Self {
        NodeIndex { inner: NodeIndexInner::new() }
    }

    /// Returns `(id, was_newly_created)`. `id`s are assigned densely in
    /// insertion order (`0, 1, 2, ...`), matching the old
    /// `dict[str, int]`-based `_get_node_id`'s `nid = len(self._index)`
    /// behavior exactly — `cfr.py`'s callers rely on this to index in
    /// lockstep into the parallel `_node_action_set_id`/`_regret`/
    /// `_strategy` arrays.
    fn get_or_create(&mut self, key: &str) -> PyResult<(u32, bool)> {
        self.inner.get_or_create_impl(key, hash_bytes)
    }

    fn __len__(&self) -> usize {
        self.inner.len()
    }

    /// Reconstructs and returns every `(original_key_string, id)` pair.
    /// Only called once, by `average_strategy()`, after training — paying
    /// one `String` allocation per entry here (not in `get_or_create`) is
    /// what keeps the hot path allocation-free.
    fn items(&self) -> Vec<(String, u32)> {
        self.inner.items()
    }
}

#[pymodule(name = "_native")]
fn native_module(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(ping, m)?)?;
    m.add_class::<NodeIndex>()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn idx() -> NodeIndexInner {
        NodeIndexInner::new()
    }

    #[test]
    fn get_or_create_returns_same_id_for_same_key() {
        let mut idx = idx();
        let (id_a, created_a) = idx.get_or_create_impl("J:xb", hash_bytes).unwrap();
        let (id_b, created_b) = idx.get_or_create_impl("J:xb", hash_bytes).unwrap();
        assert!(created_a);
        assert!(!created_b);
        assert_eq!(id_a, id_b);
    }

    #[test]
    fn get_or_create_returns_different_ids_for_different_keys() {
        let mut idx = idx();
        let (id_a, _) = idx.get_or_create_impl("J:xb", hash_bytes).unwrap();
        let (id_b, _) = idx.get_or_create_impl("Q:xb", hash_bytes).unwrap();
        assert_ne!(id_a, id_b);
        assert_eq!(idx.len(), 2);
    }

    #[test]
    fn ids_are_assigned_densely_in_insertion_order() {
        let mut idx = idx();
        let (id0, _) = idx.get_or_create_impl("a", hash_bytes).unwrap();
        let (id1, _) = idx.get_or_create_impl("b", hash_bytes).unwrap();
        let (id2, _) = idx.get_or_create_impl("c", hash_bytes).unwrap();
        // repeat lookups must not consume new ids
        let (id0_again, created_again) = idx.get_or_create_impl("a", hash_bytes).unwrap();
        assert_eq!((id0, id1, id2), (0, 1, 2));
        assert_eq!(id0_again, 0);
        assert!(!created_again);
    }

    #[test]
    fn items_round_trips_every_key_and_id() {
        let mut idx = idx();
        let inserted = ["00010203|xb|c|", "AAAA:pbc", "0102030405060708091011|x||"];
        let mut expected: Vec<(String, u32)> = Vec::new();
        for key in inserted {
            let (id, _) = idx.get_or_create_impl(key, hash_bytes).unwrap();
            expected.push((key.to_string(), id));
        }
        let mut got = idx.items();
        got.sort_by_key(|(_, id)| *id);
        expected.sort_by_key(|(_, id)| *id);
        assert_eq!(got, expected);
    }

    #[test]
    fn key_at_exactly_capacity_is_accepted() {
        let mut idx = idx();
        let key = "x".repeat(KEY_CAPACITY);
        let (id, created) = idx.get_or_create_impl(&key, hash_bytes).unwrap();
        assert!(created);
        assert_eq!(idx.items()[0].0.len(), KEY_CAPACITY);
        let _ = id;
    }

    #[test]
    fn key_one_byte_over_capacity_errors_clearly_instead_of_truncating() {
        let mut idx = idx();
        let key = "x".repeat(KEY_CAPACITY + 1);
        // `PyErr`'s `Display` impl needs an initialized interpreter to look
        // up its exception type's name — harmless to initialize repeatedly
        // (`pyo3` de-dupes this internally) and only needed under
        // `cargo test` (`--no-default-features`), not under `maturin`,
        // where the embedding Python process already did this.
        pyo3::prepare_freethreaded_python();
        let err = idx.get_or_create_impl(&key, hash_bytes).unwrap_err();
        let msg = err.to_string();
        assert!(msg.contains("exceeding NodeIndex's fixed capacity"), "{msg}");
        // Must not have silently inserted a truncated key.
        assert_eq!(idx.len(), 0);
    }

    /// A degenerate "hash function" that maps every key to the same bucket
    /// — forcing every single insert down the `overflow` collision path.
    /// With a real hash function, provoking one actual collision would
    /// need on the order of 2^32 keys; this is how the collision-safety
    /// logic (verify actual bytes, never trust the hash alone) gets
    /// exercised and proven correct without that.
    fn always_collide(_bytes: &[u8]) -> u64 {
        0
    }

    #[test]
    fn distinct_keys_stay_distinct_even_under_total_hash_collision() {
        let mut idx = idx();
        let keys = ["alpha", "beta", "gamma", "delta", "epsilon"];
        let mut ids = Vec::new();
        for key in keys {
            let (id, created) = idx.get_or_create_impl(key, always_collide).unwrap();
            assert!(created, "{key} should be newly created");
            ids.push(id);
        }
        // All distinct ids despite every key hashing to 0.
        let mut sorted = ids.clone();
        sorted.sort_unstable();
        sorted.dedup();
        assert_eq!(sorted.len(), keys.len());

        // Re-querying every key (still under total collision) returns the
        // SAME id it got the first time, not a new one and not another
        // key's id.
        for (key, &expected_id) in keys.iter().zip(&ids) {
            let (id, created) = idx.get_or_create_impl(key, always_collide).unwrap();
            assert!(!created, "{key} should already exist");
            assert_eq!(id, expected_id, "{key} must resolve to its own id");
        }
        assert_eq!(idx.len(), keys.len());

        // And the reconstructed keys are exactly right, not mixed up.
        let mut items = idx.items();
        items.sort_by_key(|(_, id)| *id);
        let mut expected: Vec<(String, u32)> =
            keys.iter().map(|&k| k.to_string()).zip(ids.iter().copied()).collect();
        expected.sort_by_key(|(_, id)| *id);
        assert_eq!(items, expected);
    }

    #[test]
    fn arena_chunk_boundary_is_handled_correctly() {
        // Insert enough distinct keys to span at least one chunk rollover
        // and verify every id still resolves to its own correct key.
        let mut idx = idx();
        let n = CHUNK_LEN + 10;
        let mut ids = Vec::with_capacity(n);
        for i in 0..n {
            let key = format!("{i:08}");
            let (id, created) = idx.get_or_create_impl(&key, hash_bytes).unwrap();
            assert!(created);
            ids.push(id);
        }
        for (i, &id) in ids.iter().enumerate() {
            assert_eq!(decode(idx.arena.get(id)), format!("{i:08}"));
        }
    }
}
