//! Rust port of the recursive best-response/actual-value walk
//! (`_av_walk`/`_br_walk`/`best_response_value` in
//! `cfr_solver/exploitability.py`), specialized to `PostflopSubgame`
//! (Stage 8R-4). Single-threaded -- parallelizing the per-combo-pair
//! subtrees is Stage 8R-5, a separate later stage.
//!
//! This is a direct structural port: every branch below mirrors the exact
//! branch in `exploitability.py`, in the same order, doing the same
//! floating-point operations in the same order, so that the result is
//! bit-exact with the Python reference (verified in
//! `tests/test_exploitability_native.py`). See each function's docstring
//! for the specific correspondence to its Python counterpart.

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
