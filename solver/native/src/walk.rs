//! Rust port of the recursive best-response/actual-value walk
//! (`_av_walk`/`_br_walk`/`best_response_value` in
//! `cfr_solver/exploitability.py`), specialized to `PostflopSubgame`
//! (Stage 8R-4). Stage 8R-5 (below the `-- Stage 8R-5 --` marker) adds
//! Rayon-parallel counterparts of every function above that marker,
//! without changing any of them.
//!
//! This is a direct structural port: every branch below mirrors the exact
//! branch in `exploitability.py`, in the same order, doing the same
//! floating-point operations in the same order, so that the result is
//! bit-exact with the Python reference (verified in
//! `tests/test_exploitability_native.py`). See each function's docstring
//! for the specific correspondence to its Python counterpart.

use rayon::prelude::*;
use rustc_hash::FxHashMap;

use crate::history::{BoardBuf, Combo, History, TokenBuf};
use crate::rules;
use crate::strategy::{action_index, AvgStrategy};

/// Everything the walk needs about the concrete `PostflopSubgame` instance,
/// gathered in one place so the recursive functions below don't have to
/// thread five separate parameters through every call.
pub struct GameCtx {
    pub hero_combos: Vec<Combo>,
    pub villain_combos: Vec<Combo>,
    pub preflop_contrib: (f64, f64),
    pub bet_sizes: (f64, f64, f64),
    pub max_wagers_per_round: u32,
}

impl GameCtx {
    pub fn initial_history(&self, flop_board: [u8; 3]) -> History {
        History {
            hero_combo: None,
            villain_combo: None,
            board: BoardBuf::from_slice(&flop_board),
            flop_a: TokenBuf::EMPTY,
            turn_a: TokenBuf::EMPTY,
            river_a: TokenBuf::EMPTY,
        }
    }
}

/// One-byte betting action as a `&str` without heap allocation --
/// `rules::next_history` takes `&str` (matching Python's `Action = str`),
/// but every betting action here is always exactly one ASCII byte.
#[inline]
fn next_history_for_action(ctx: &GameCtx, h: &History, action: u8) -> History {
    let buf = [action];
    let s = std::str::from_utf8(&buf).expect("action byte is always ASCII");
    rules::next_history(h, &ctx.hero_combos, &ctx.villain_combos, s)
}

fn own_combo_for(h: &History, player: u8) -> Combo {
    if player == 0 {
        h.hero_combo.expect("player 0's combo must be dealt before it can act")
    } else {
        h.villain_combo.expect("player 1's combo must be dealt before it can act")
    }
}

/// Direct port of `_av_walk`: terminal -> `returns`; chance node ->
/// probability-weighted sum over `chance_outcomes`; decision node ->
/// strategy-weighted sum using `avg.strategy_at` (mirrors `_strategy_at`'s
/// uniform fallback exactly).
pub fn av_walk(ctx: &GameCtx, avg: &AvgStrategy, h: History) -> [f64; 2] {
    if rules::is_terminal(&h) {
        return rules::returns(
            h.hero_combo.unwrap(),
            h.villain_combo.unwrap(),
            &h.board,
            &h.flop_a,
            &h.turn_a,
            &h.river_a,
            ctx.preflop_contrib,
            ctx.bet_sizes,
        );
    }

    if rules::is_chance_node(&h) {
        let outcomes = rules::chance_outcomes(
            &ctx.hero_combos,
            &ctx.villain_combos,
            h.hero_combo,
            h.villain_combo,
            &h.board,
        )
        .expect("chance_outcomes must succeed on a reachable chance node");
        let mut total = [0.0f64; 2];
        for (action, prob) in outcomes {
            let child_h = rules::next_history(&h, &ctx.hero_combos, &ctx.villain_combos, &action);
            let child = av_walk(ctx, avg, child_h);
            total[0] += prob * child[0];
            total[1] += prob * child[1];
        }
        return total;
    }

    let player = rules::current_player(&h, ctx.bet_sizes);
    let actions = rules::legal_actions(&h, ctx.bet_sizes, ctx.max_wagers_per_round);
    let own_combo = own_combo_for(&h, player);
    let key = rules::information_set_key(own_combo, &h.board, &h.flop_a, &h.turn_a, &h.river_a);
    let strat = avg.strategy_at(&key, &actions);

    let mut total = [0.0f64; 2];
    for &a in &actions {
        let child_h = next_history_for_action(ctx, &h, a);
        let child = av_walk(ctx, avg, child_h);
        let p = strat[action_index(a)];
        total[0] += p * child[0];
        total[1] += p * child[1];
    }
    total
}

/// One accumulator bucket for a single information-set key inside `q_accum`:
/// mirrors Python's `q_accum[key]: dict[Action, float]`, but since the same
/// key always has the same legal-action set (the key encodes the exact
/// action tokens that determine legality), we can store the ordered list of
/// legal actions once (in the order `legal_actions` produced them, matching
/// Python dict insertion order) alongside a fixed 4-slot value row.
#[derive(Clone, Copy)]
pub struct QEntry {
    order: [u8; 3],
    len: u8,
    vals: [f64; 4],
}

impl QEntry {
    fn new(actions: &[u8]) -> Self {
        debug_assert!(actions.len() <= 3, "at most 3 actions are ever legal at once");
        let mut order = [0u8; 3];
        order[..actions.len()].copy_from_slice(actions);
        QEntry { order, len: actions.len() as u8, vals: [0.0; 4] }
    }

    fn order(&self) -> &[u8] {
        &self.order[..self.len as usize]
    }

    /// The action achieving the maximum accumulated value, breaking ties by
    /// keeping the first (in insertion/`actions` order) maximal action --
    /// matches Python's `max(vals.items(), key=lambda kv: kv[1])[0]`, which
    /// keeps the first-seen item on a tie because `max` only replaces its
    /// current best on a strict `>`.
    fn argmax(&self) -> u8 {
        let mut best = self.order[0];
        let mut best_val = self.vals[action_index(best)];
        for &a in &self.order()[1..] {
            let v = self.vals[action_index(a)];
            if v > best_val {
                best_val = v;
                best = a;
            }
        }
        best
    }
}

type Policy = FxHashMap<Box<str>, u8>;
type QAccum = FxHashMap<Box<str>, QEntry>;

/// Direct port of `_br_walk`. At `player`'s own decision nodes: computes
/// every legal action's child value, accumulates
/// `q_accum[key][a] += reach_others * child_values[a]` for every legal
/// action `a` (in the same order `actions` lists them, matching Python's
/// dict-insertion-order iteration -- load-bearing for bit-exact floating
/// point), then returns `child_values[policy[key]]` (falling back to a
/// uniform average over `child_values`, in `actions` order, when `key` has
/// no policy entry yet). At opponent decision nodes: same
/// strategy-weighted-sum as `_av_walk`'s decision branch, but threading
/// `reach_others * strat[a]` into each recursive call. At chance nodes: same
/// probability-weighted recursion as `_av_walk`, threading
/// `reach_others * prob` into each recursive call.
pub fn br_walk(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    player: u8,
    policy: &Policy,
    h: History,
    reach_others: f64,
    q_accum: &mut QAccum,
) -> f64 {
    if rules::is_terminal(&h) {
        let r = rules::returns(
            h.hero_combo.unwrap(),
            h.villain_combo.unwrap(),
            &h.board,
            &h.flop_a,
            &h.turn_a,
            &h.river_a,
            ctx.preflop_contrib,
            ctx.bet_sizes,
        );
        return r[player as usize];
    }

    if rules::is_chance_node(&h) {
        let outcomes = rules::chance_outcomes(
            &ctx.hero_combos,
            &ctx.villain_combos,
            h.hero_combo,
            h.villain_combo,
            &h.board,
        )
        .expect("chance_outcomes must succeed on a reachable chance node");
        let mut total = 0.0f64;
        for (action, prob) in outcomes {
            let child_h = rules::next_history(&h, &ctx.hero_combos, &ctx.villain_combos, &action);
            total += prob * br_walk(ctx, avg, player, policy, child_h, reach_others * prob, q_accum);
        }
        return total;
    }

    let acting = rules::current_player(&h, ctx.bet_sizes);
    let actions = rules::legal_actions(&h, ctx.bet_sizes, ctx.max_wagers_per_round);

    if acting == player {
        let own_combo = own_combo_for(&h, player);
        let key = rules::information_set_key(own_combo, &h.board, &h.flop_a, &h.turn_a, &h.river_a);

        let mut child_values = [0.0f64; 4];
        for &a in &actions {
            let child_h = next_history_for_action(ctx, &h, a);
            let v = br_walk(ctx, avg, player, policy, child_h, reach_others, q_accum);
            child_values[action_index(a)] = v;
        }

        let bucket = q_accum
            .entry(key.clone().into_boxed_str())
            .or_insert_with(|| QEntry::new(&actions));
        for &a in &actions {
            bucket.vals[action_index(a)] += reach_others * child_values[action_index(a)];
        }

        match policy.get(key.as_str()) {
            Some(&chosen) => child_values[action_index(chosen)],
            None => {
                let mut sum = 0.0f64;
                for &a in &actions {
                    sum += child_values[action_index(a)];
                }
                sum / actions.len() as f64
            }
        }
    } else {
        let own_combo = own_combo_for(&h, acting);
        let key = rules::information_set_key(own_combo, &h.board, &h.flop_a, &h.turn_a, &h.river_a);
        let strat = avg.strategy_at(&key, &actions);

        let mut total = 0.0f64;
        for &a in &actions {
            let p = strat[action_index(a)];
            let child_h = next_history_for_action(ctx, &h, a);
            total += p * br_walk(ctx, avg, player, policy, child_h, reach_others * p, q_accum);
        }
        total
    }
}

/// Direct port of `best_response_value`'s policy-iteration loop: each sweep
/// walks the full tree once (fresh `q_accum`) using the *previous* sweep's
/// frozen `policy`, then greedily updates every information set that
/// appeared this sweep to its argmax action; stops on an exact fixed point
/// (`new_policy == policy`), matching Python's dict equality check bit for
/// bit (both key set and, per key, the chosen action must match). Returns
/// `Err` if not converged within `max_sweeps` sweeps, mirroring Python's
/// `RuntimeError`.
pub fn best_response_value(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    player: u8,
    flop_board: [u8; 3],
    max_sweeps: u32,
) -> Result<f64, String> {
    let mut policy: Policy = FxHashMap::default();
    let mut converged = false;

    for _ in 0..max_sweeps {
        let mut q_accum: QAccum = FxHashMap::default();
        let init = ctx.initial_history(flop_board);
        br_walk(ctx, avg, player, &policy, init, 1.0, &mut q_accum);

        let mut new_policy: Policy = FxHashMap::default();
        new_policy.reserve(q_accum.len());
        for (key, entry) in q_accum.iter() {
            new_policy.insert(key.clone(), entry.argmax());
        }

        if new_policy == policy {
            converged = true;
            break;
        }
        policy = new_policy;
    }

    if !converged {
        return Err(format!(
            "best_response_value did not converge within {max_sweeps} sweeps for player \
             {player} -- the games in this package are small finite-horizon games and should \
             converge in a handful of sweeps, so this indicates a bug"
        ));
    }

    let mut throwaway: QAccum = FxHashMap::default();
    let init = ctx.initial_history(flop_board);
    Ok(br_walk(ctx, avg, player, &policy, init, 1.0, &mut throwaway))
}

/// Direct port of `actual_value`: `_av_walk` from the game's initial
/// history.
pub fn actual_value(ctx: &GameCtx, avg: &AvgStrategy, flop_board: [u8; 3]) -> [f64; 2] {
    av_walk(ctx, avg, ctx.initial_history(flop_board))
}

/// Direct port of `exploitability_per_player`, specialized to the fixed
/// 2-player case: `[best_response_value(p) - actual_value()[p] for p in (0, 1)]`.
pub fn exploitability_per_player(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    flop_board: [u8; 3],
    max_sweeps: u32,
) -> Result<[f64; 2], String> {
    let actual = actual_value(ctx, avg, flop_board);
    let mut gaps = [0.0f64; 2];
    for player in 0u8..2 {
        let br = best_response_value(ctx, avg, player, flop_board, max_sweeps)?;
        gaps[player as usize] = br - actual[player as usize];
    }
    Ok(gaps)
}

/// Direct port of `exploitability`: the average of `exploitability_per_player`.
pub fn exploitability(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    flop_board: [u8; 3],
    max_sweeps: u32,
) -> Result<f64, String> {
    let gaps = exploitability_per_player(ctx, avg, flop_board, max_sweeps)?;
    Ok((gaps[0] + gaps[1]) / 2.0)
}

// ============================================================================
// -- Stage 8R-5: Rayon-parallel counterparts --------------------------------
// ============================================================================
//
// Direct structural port of `exploitability.py`'s "Parallel exploitability"
// section (Stage 7) -- `expand_chance_prefix`/`fold_chance_prefix_actual`/
// `fold_chance_prefix_br` below are line-for-line translations of that
// module's `_expand_chance_prefix`/`_fold_chance_prefix_actual`/
// `_fold_chance_prefix_br`. See that module's docstrings (and
// `solver/BENCHMARKS.md`'s Stage 7 entry) for the full argument that this
// design reproduces the sequential walk's floating-point result bit-for-bit,
// not just approximately -- the summary:
//
// - `expand_chance_prefix` descends through consecutive chance nodes from
//   the root using ONLY the generic `is_chance_node`/`chance_outcomes`/
//   `next_history` primitives (no `PostflopSubgame`-specific "two levels"
//   hardcoding), collecting every leaf reached (both hero and villain combos
//   dealt) in the same depth-first order `chance_outcomes` enumerates them,
//   paired with the cumulative chance-reach probability to that point --
//   `reach * prob`, same expression, same order, at every level, exactly
//   reproducing what `reach_others` would hold at that point in the
//   sequential recursion.
// - The leaf-level computation (`av_walk`/`br_walk`, wholly unmodified) runs
//   in parallel via `.par_iter().map(..).collect::<Vec<_>>()` -- an indexed
//   parallel iterator, so `collect` returns results in the SAME order as the
//   input `Vec`, regardless of which thread computed which element.
// - `fold_chance_prefix_actual`/`fold_chance_prefix_br` then walk the exact
//   same chance-node prefix a second time, single-threaded, popping the next
//   precomputed leaf result off the collected `Vec` (via its iterator) in
//   that same depth-first order instead of recursing further -- every
//   `total += prob * child` here is the identical expression, in the
//   identical order, that `av_walk`/`br_walk`'s chance-node branch would
//   have executed, so this is not a reduction (`reduce()`/`fold()`) that
//   could reassociate the additions, just a replay of the same left-to-right
//   accumulation the sequential version already does.
// - For `br_walk`'s `q_accum`: each leaf's own subtree can only ever touch a
//   given (key, action) more than once if the sequential recursion would
//   too (this is unmodified code, just given a scoped-local accumulator), so
//   a leaf's `local_q` is exactly what `br_walk` would have written into a
//   shared `q_accum` while visiting that leaf's subtree. Merging `local_q`
//   maps across leaves via a left-to-right `+=` fold, in the same DFS
//   (combo-pair enumeration) order the sequential recursion visits them,
//   reproduces that shared accumulation exactly -- a mathematical property
//   of left folds (`foldl(f, z, xs ++ ys) == foldl(f, foldl(f, z, xs), ys)`)
//   that holds regardless of which thread computed which leaf's `local_q`.
//   No node above the leaf level ever touches `q_accum` (every node from the
//   root down to a leaf is a chance node dealing hero's or villain's combo,
//   never `player`'s own decision node), so leaf-local + merge captures every
//   contribution with nothing left over.

/// Descend through consecutive chance nodes from `h` (for `PostflopSubgame`:
/// exactly two -- "deal hero's combo", then "deal villain's combo" -- the
/// turn/river card draws happen *inside* the decision subtree below each
/// leaf, not in this prefix, since `is_chance_node` is false as soon as both
/// combos are dealt and the flop round hasn't ended yet), returning every
/// leaf reached in the same depth-first order `rules::chance_outcomes`
/// visits them, paired with the cumulative chance-reach probability of
/// getting there. Direct port of `exploitability.py`'s
/// `_expand_chance_prefix` (Stage 7). One leaf here is exactly one
/// hero-combo x villain-combo pair -- the unit of parallel work below.
pub fn expand_chance_prefix(ctx: &GameCtx, h: History, reach: f64) -> Vec<(History, f64)> {
    if !rules::is_chance_node(&h) {
        return vec![(h, reach)];
    }
    let outcomes = rules::chance_outcomes(
        &ctx.hero_combos,
        &ctx.villain_combos,
        h.hero_combo,
        h.villain_combo,
        &h.board,
    )
    .expect("chance_outcomes must succeed on a reachable chance node");
    let mut leaves = Vec::new();
    for (action, prob) in outcomes {
        let child_h = rules::next_history(&h, &ctx.hero_combos, &ctx.villain_combos, &action);
        leaves.extend(expand_chance_prefix(ctx, child_h, reach * prob));
    }
    leaves
}

/// The mirror image of `expand_chance_prefix` for `actual_value`: walks the
/// exact same chance-node prefix in the exact same order, but instead of
/// computing a leaf's value by recursing further, pops the next precomputed
/// per-leaf value off `results` (an iterator already advancing in the same
/// depth-first order `expand_chance_prefix` produced). Direct port of
/// `exploitability.py`'s `_fold_chance_prefix_actual`.
fn fold_chance_prefix_actual(
    ctx: &GameCtx,
    h: History,
    results: &mut std::vec::IntoIter<[f64; 2]>,
) -> [f64; 2] {
    if !rules::is_chance_node(&h) {
        return results.next().expect("results iterator exhausted before every leaf was folded");
    }
    let outcomes = rules::chance_outcomes(
        &ctx.hero_combos,
        &ctx.villain_combos,
        h.hero_combo,
        h.villain_combo,
        &h.board,
    )
    .expect("chance_outcomes must succeed on a reachable chance node");
    let mut total = [0.0f64; 2];
    for (action, prob) in outcomes {
        let child_h = rules::next_history(&h, &ctx.hero_combos, &ctx.villain_combos, &action);
        let child = fold_chance_prefix_actual(ctx, child_h, results);
        total[0] += prob * child[0];
        total[1] += prob * child[1];
    }
    total
}

/// The mirror image of `expand_chance_prefix` for `best_response_value`:
/// walks the same chance-node prefix in the same order, and at each leaf
/// pops the next precomputed `(value, local_q)` pair off `results`, merging
/// `local_q`'s buckets into the shared `q_accum` via `+=` (see this
/// module's Stage 8R-5 section docs for why that reproduces the sequential
/// `bucket[a] += reach_others * child_values[a]` accumulation exactly, in
/// the same order, regardless of which thread computed which leaf). Direct
/// port of `exploitability.py`'s `_fold_chance_prefix_br`.
fn fold_chance_prefix_br(
    ctx: &GameCtx,
    h: History,
    results: &mut std::vec::IntoIter<(f64, QAccum)>,
    q_accum: &mut QAccum,
) -> f64 {
    if !rules::is_chance_node(&h) {
        let (value, local_q) =
            results.next().expect("results iterator exhausted before every leaf was folded");
        for (key, entry) in local_q {
            let bucket = q_accum.entry(key).or_insert_with(|| QEntry::new(entry.order()));
            for &a in entry.order() {
                bucket.vals[action_index(a)] += entry.vals[action_index(a)];
            }
        }
        return value;
    }
    let outcomes = rules::chance_outcomes(
        &ctx.hero_combos,
        &ctx.villain_combos,
        h.hero_combo,
        h.villain_combo,
        &h.board,
    )
    .expect("chance_outcomes must succeed on a reachable chance node");
    let mut total = 0.0f64;
    for (action, prob) in outcomes {
        let child_h = rules::next_history(&h, &ctx.hero_combos, &ctx.villain_combos, &action);
        total += prob * fold_chance_prefix_br(ctx, child_h, results, q_accum);
    }
    total
}

/// Runs `f` inside a scoped Rayon thread pool of `max_workers` threads when
/// given, or the ambient (global default, `RAYON_NUM_THREADS`-controlled)
/// pool when `None` -- scoped to this one call only, never mutating any
/// global Rayon state, per Rayon's `ThreadPoolBuilder`/`ThreadPool::install`
/// API.
pub fn with_worker_pool<F, R>(max_workers: Option<u32>, f: F) -> R
where
    F: FnOnce() -> R + Send,
    R: Send,
{
    match max_workers {
        Some(n) if n > 0 => {
            let pool = rayon::ThreadPoolBuilder::new()
                .num_threads(n as usize)
                .build()
                .expect("failed to build a scoped Rayon thread pool");
            pool.install(f)
        }
        _ => f(),
    }
}

/// Parallel, per-combo-pair equivalent of `actual_value`. Bit-exact with
/// `actual_value` regardless of how many threads actually do the work (see
/// this module's Stage 8R-5 section docs) -- verified in
/// `tests/test_exploitability_native_parallel.py`.
pub fn actual_value_parallel(ctx: &GameCtx, avg: &AvgStrategy, flop_board: [u8; 3]) -> [f64; 2] {
    let init = ctx.initial_history(flop_board);
    let leaves = expand_chance_prefix(ctx, init, 1.0);

    // -- parallel phase: independent per-leaf subtree walks, no shared state.
    let leaf_values: Vec<[f64; 2]> =
        leaves.par_iter().map(|&(h, _reach)| av_walk(ctx, avg, h)).collect();

    // -- sequential phase: order-preserving replay of the same chance-node
    // additions `av_walk` itself would have performed.
    let mut results = leaf_values.into_iter();
    fold_chance_prefix_actual(ctx, init, &mut results)
}

/// One sweep's per-leaf work for `best_response_value_parallel`: computes,
/// for every combo-pair leaf, that leaf's own subtree walk (using the
/// *previous* sweep's frozen `policy`) into a fresh, leaf-local `QAccum` --
/// exactly what `br_walk` would do if given a shared `q_accum`, just scoped
/// to one leaf's own contributions so it can run independently of every
/// other leaf.
fn br_sweep_leaf_results(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    player: u8,
    policy: &Policy,
    leaves: &[(History, f64)],
) -> Vec<(f64, QAccum)> {
    leaves
        .par_iter()
        .map(|&(h, reach)| {
            let mut local_q: QAccum = FxHashMap::default();
            let value = br_walk(ctx, avg, player, policy, h, reach, &mut local_q);
            (value, local_q)
        })
        .collect()
}

/// Parallel, per-combo-pair equivalent of `best_response_value`. Same
/// policy-iteration structure as the sequential version (same convergence
/// guarantee, same `max_sweeps` safety cap, same exact-fixed-point check):
/// each sweep dispatches every combo pair's subtree walk across the Rayon
/// pool using the previous sweep's frozen `policy`, then folds the results
/// back into one `q_accum` and one greedy policy update exactly as the
/// sequential version would, before moving to the next sweep. Only the
/// per-leaf subtree walks run in parallel -- the sweep loop itself, like the
/// sequential version's, is inherently iterative (each sweep genuinely needs
/// the previous one's completed policy) and stays single-threaded. Bit-exact
/// with `best_response_value` regardless of thread count -- verified in
/// `tests/test_exploitability_native_parallel.py`.
pub fn best_response_value_parallel(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    player: u8,
    flop_board: [u8; 3],
    max_sweeps: u32,
) -> Result<f64, String> {
    let init = ctx.initial_history(flop_board);
    let leaves = expand_chance_prefix(ctx, init, 1.0);

    let mut policy: Policy = FxHashMap::default();
    let mut converged = false;

    for _ in 0..max_sweeps {
        let leaf_results = br_sweep_leaf_results(ctx, avg, player, &policy, &leaves);
        let mut q_accum: QAccum = FxHashMap::default();
        let mut results = leaf_results.into_iter();
        fold_chance_prefix_br(ctx, init, &mut results, &mut q_accum);

        let mut new_policy: Policy = FxHashMap::default();
        new_policy.reserve(q_accum.len());
        for (key, entry) in q_accum.iter() {
            new_policy.insert(key.clone(), entry.argmax());
        }

        if new_policy == policy {
            converged = true;
            break;
        }
        policy = new_policy;
    }

    if !converged {
        return Err(format!(
            "best_response_value_parallel did not converge within {max_sweeps} sweeps for \
             player {player} -- the games in this package are small finite-horizon games and \
             should converge in a handful of sweeps, so this indicates a bug"
        ));
    }

    let final_results = br_sweep_leaf_results(ctx, avg, player, &policy, &leaves);
    let mut throwaway: QAccum = FxHashMap::default();
    let mut results = final_results.into_iter();
    Ok(fold_chance_prefix_br(ctx, init, &mut results, &mut throwaway))
}

/// Parallel equivalent of `exploitability_per_player`. Bit-exact with
/// `exploitability_per_player` regardless of thread count.
pub fn exploitability_per_player_parallel(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    flop_board: [u8; 3],
    max_sweeps: u32,
) -> Result<[f64; 2], String> {
    let actual = actual_value_parallel(ctx, avg, flop_board);
    let mut gaps = [0.0f64; 2];
    for player in 0u8..2 {
        let br = best_response_value_parallel(ctx, avg, player, flop_board, max_sweeps)?;
        gaps[player as usize] = br - actual[player as usize];
    }
    Ok(gaps)
}

/// Parallel equivalent of `exploitability`: the average of
/// `exploitability_per_player_parallel`. Bit-exact with `exploitability`
/// regardless of thread count.
pub fn exploitability_parallel(
    ctx: &GameCtx,
    avg: &AvgStrategy,
    flop_board: [u8; 3],
    max_sweeps: u32,
) -> Result<f64, String> {
    let gaps = exploitability_per_player_parallel(ctx, avg, flop_board, max_sweeps)?;
    Ok((gaps[0] + gaps[1]) / 2.0)
}

#[cfg(test)]
mod parallel_tests {
    use super::*;

    fn tiny_ctx() -> GameCtx {
        // AA (2 combos) vs KK (2 combos), matching
        // `tests/test_exploitability_native.py`'s `_tiny_game` slice --
        // small enough to run instantly as a `cargo test`.
        GameCtx {
            hero_combos: vec![(51, 47), (51, 46)], // As/Ah, As/Ad-ish stand-ins; exact ids
            // don't matter for this structural test, only that they're two
            // distinct combos disjoint from the villain combos and the board.
            villain_combos: vec![(45, 41), (45, 40)],
            preflop_contrib: (2.5, 2.5),
            bet_sizes: (2.5, 5.0, 7.5),
            max_wagers_per_round: 1,
        }
    }

    fn flop_board() -> [u8; 3] {
        [0, 4, 8]
    }

    #[test]
    fn combo_pair_leaf_count_matches_hero_times_villain_combos() {
        let ctx = tiny_ctx();
        let init = ctx.initial_history(flop_board());
        let leaves = expand_chance_prefix(&ctx, init, 1.0);
        assert_eq!(leaves.len(), ctx.hero_combos.len() * ctx.villain_combos.len());
        let total_prob: f64 = leaves.iter().map(|&(_, p)| p).sum();
        assert!(
            (total_prob - 1.0).abs() < 1e-12,
            "leaf probabilities should sum to ~1.0, got {total_prob}"
        );
    }

    #[test]
    fn expand_then_fold_actual_reproduces_plain_av_walk_sequentially() {
        // Isolates "did enumeration order match" from "did parallelism
        // introduce a bug" -- process leaves sequentially through the new
        // expand/fold machinery (no Rayon involved yet) and confirm it's
        // bit-identical to calling `av_walk` directly from the root.
        let ctx = tiny_ctx();
        let avg = AvgStrategy::from_entries([]);
        let init = ctx.initial_history(flop_board());

        let expected = av_walk(&ctx, &avg, init);

        let leaves = expand_chance_prefix(&ctx, init, 1.0);
        let leaf_values: Vec<[f64; 2]> =
            leaves.iter().map(|&(h, _reach)| av_walk(&ctx, &avg, h)).collect();
        let mut results = leaf_values.into_iter();
        let got = fold_chance_prefix_actual(&ctx, init, &mut results);

        assert_eq!(got, expected);
    }

    #[test]
    fn actual_value_parallel_matches_sequential_actual_value() {
        let ctx = tiny_ctx();
        let avg = AvgStrategy::from_entries([]);
        let expected = actual_value(&ctx, &avg, flop_board());
        let got = actual_value_parallel(&ctx, &avg, flop_board());
        assert_eq!(got, expected);
    }

    #[test]
    fn best_response_value_parallel_matches_sequential_best_response_value() {
        let ctx = tiny_ctx();
        let avg = AvgStrategy::from_entries([]);
        for player in 0u8..2 {
            let expected = best_response_value(&ctx, &avg, player, flop_board(), 50).unwrap();
            let got = best_response_value_parallel(&ctx, &avg, player, flop_board(), 50).unwrap();
            assert_eq!(got, expected);
        }
    }

    #[test]
    fn with_worker_pool_none_and_some_produce_the_same_result() {
        let ctx = tiny_ctx();
        let avg = AvgStrategy::from_entries([]);
        let a = with_worker_pool(None, || actual_value_parallel(&ctx, &avg, flop_board()));
        let b = with_worker_pool(Some(1), || actual_value_parallel(&ctx, &avg, flop_board()));
        let c = with_worker_pool(Some(2), || actual_value_parallel(&ctx, &avg, flop_board()));
        assert_eq!(a, b);
        assert_eq!(b, c);
    }
}
