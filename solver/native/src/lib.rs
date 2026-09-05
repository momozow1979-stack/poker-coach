//! Stage 8R-1 set up build/CI plumbing only (the no-op `ping()` below).
//! Stage 8R-2 added a Rust port of the poker hand evaluator in `cards.rs`.
//! Stage 8R-3 adds a Rust port of `PostflopSubgame`'s game-rule logic in
//! `history.rs`/`rules.rs`, exposed below only as debug/test bindings
//! (`_debug_*`) exercised exhaustively against the live Python
//! implementation in `tests/test_native_postflop_rules.py` -- not used by
//! any production code path yet. The exploitability walk, `avg_strategy`
//! handling, and training itself are still pure Python -- later stages, not
//! this one.

use pyo3::exceptions::{PyRuntimeError, PyValueError};
use pyo3::prelude::*;
use pyo3::types::PyDict;

mod cards;
mod history;
mod rules;
mod strategy;
mod walk;

use history::{BoardBuf, History, TokenBuf};
use strategy::AvgStrategy;
use walk::GameCtx;

/// Trivial no-op used to verify the native extension loads and runs.
#[pyfunction]
fn ping() -> i64 {
    42
}

/// Test-only binding for `cards::evaluate_5card`, exercised exhaustively
/// against the Python reference implementation in
/// `tests/test_native_cards.py`. Not used by any production code path yet.
#[pyfunction]
fn evaluate_5card_native(cards: [u8; 5]) -> u32 {
    cards::evaluate_5card(cards)
}

/// Test-only binding for `cards::evaluate_best_hand` (5, 6, or 7 cards).
#[pyfunction]
fn evaluate_best_hand_native(cards: Vec<u8>) -> u32 {
    cards::evaluate_best_hand(&cards)
}

// -- Stage 8R-3 debug bindings: `PostflopSubgame` game-rule logic ----------
//
// These take plain, FFI-friendly types (strings, tuples, ints) rather than
// exposing `History`/`TokenBuf`/`BoardBuf` directly to Python -- a thin
// conversion layer here, matching the convention `evaluate_5card_native`
// already set. Every one of these is compared against the live Python
// implementation exhaustively in `tests/test_native_postflop_rules.py`.

#[pyfunction]
fn _debug_round_done(tokens: String) -> bool {
    rules::round_done(&TokenBuf::from_str(&tokens))
}

#[pyfunction]
fn _debug_round_folded(tokens: String) -> bool {
    rules::round_folded(&TokenBuf::from_str(&tokens))
}

#[pyfunction]
fn _debug_legal_for_tokens(tokens: String, max_wagers: u32) -> PyResult<Vec<String>> {
    rules::legal_for_tokens(&TokenBuf::from_str(&tokens), max_wagers)
        .map(|bytes| bytes.into_iter().map(|b| (b as char).to_string()).collect())
        .map_err(PyValueError::new_err)
}

#[pyfunction]
fn _debug_simulate_round(tokens: String, bet_size: f64) -> ((f64, f64), Option<u8>) {
    rules::simulate_round(&TokenBuf::from_str(&tokens), bet_size)
}

#[pyfunction]
fn _debug_active_round_for(
    board: Vec<u8>,
    flop_a: String,
    turn_a: String,
    river_a: String,
    bet_sizes: (f64, f64, f64),
) -> Option<(String, f64, u8)> {
    let board = BoardBuf::from_slice(&board);
    rules::active_round_for(
        &board,
        &TokenBuf::from_str(&flop_a),
        &TokenBuf::from_str(&turn_a),
        &TokenBuf::from_str(&river_a),
        bet_sizes,
    )
    .map(|(tokens, bet_size, street)| (tokens.as_str().to_string(), bet_size, street))
}

#[pyfunction]
#[pyo3(signature = (hero_combo, villain_combo, board, flop_a, turn_a, river_a, player))]
fn _debug_information_set_key(
    hero_combo: Option<(u8, u8)>,
    villain_combo: Option<(u8, u8)>,
    board: Vec<u8>,
    flop_a: String,
    turn_a: String,
    river_a: String,
    player: u8,
) -> String {
    let own_combo = if player == 0 { hero_combo } else { villain_combo }
        .expect("information_set_key requires the acting player's combo to be dealt");
    rules::information_set_key(
        own_combo,
        &BoardBuf::from_slice(&board),
        &TokenBuf::from_str(&flop_a),
        &TokenBuf::from_str(&turn_a),
        &TokenBuf::from_str(&river_a),
    )
}

#[pyfunction]
#[pyo3(signature = (hero_combos, villain_combos, hero_combo, villain_combo, board))]
fn _debug_chance_outcomes(
    hero_combos: Vec<(u8, u8)>,
    villain_combos: Vec<(u8, u8)>,
    hero_combo: Option<(u8, u8)>,
    villain_combo: Option<(u8, u8)>,
    board: Vec<u8>,
) -> PyResult<Vec<(String, f64)>> {
    rules::chance_outcomes(
        &hero_combos,
        &villain_combos,
        hero_combo,
        villain_combo,
        &BoardBuf::from_slice(&board),
    )
    .map_err(PyRuntimeError::new_err)
}

#[pyfunction]
#[pyo3(signature = (hero_combo, villain_combo, board, flop_a, turn_a, river_a))]
fn _debug_is_terminal(
    hero_combo: Option<(u8, u8)>,
    villain_combo: Option<(u8, u8)>,
    board: Vec<u8>,
    flop_a: String,
    turn_a: String,
    river_a: String,
) -> bool {
    let h = History {
        hero_combo,
        villain_combo,
        board: BoardBuf::from_slice(&board),
        flop_a: TokenBuf::from_str(&flop_a),
        turn_a: TokenBuf::from_str(&turn_a),
        river_a: TokenBuf::from_str(&river_a),
    };
    rules::is_terminal(&h)
}

#[pyfunction]
fn _debug_current_player(
    board: Vec<u8>,
    flop_a: String,
    turn_a: String,
    river_a: String,
    bet_sizes: (f64, f64, f64),
) -> u8 {
    let h = History {
        hero_combo: None,
        villain_combo: None,
        board: BoardBuf::from_slice(&board),
        flop_a: TokenBuf::from_str(&flop_a),
        turn_a: TokenBuf::from_str(&turn_a),
        river_a: TokenBuf::from_str(&river_a),
    };
    rules::current_player(&h, bet_sizes)
}

#[pyfunction]
fn _debug_returns(
    hero_combo: (u8, u8),
    villain_combo: (u8, u8),
    board: Vec<u8>,
    flop_a: String,
    turn_a: String,
    river_a: String,
    preflop_contrib: (f64, f64),
    bet_sizes: (f64, f64, f64),
) -> (f64, f64) {
    let r = rules::returns(
        hero_combo,
        villain_combo,
        &BoardBuf::from_slice(&board),
        &TokenBuf::from_str(&flop_a),
        &TokenBuf::from_str(&turn_a),
        &TokenBuf::from_str(&river_a),
        preflop_contrib,
        bet_sizes,
    );
    (r[0], r[1])
}

// -- Stage 8R-4: the real exploitability walk, exposed as public API -------
//
// Unlike the Stage 8R-3 `_debug_*` bindings above (test-only scaffolding),
// these four functions are the actual production-facing native API: the
// thin Python wrapper in `cfr_solver/exploitability_native.py` calls these
// directly. `avg_strategy` is converted from the Python dict to
// `AvgStrategy` exactly once per call here -- never re-done per combo pair
// or per policy-iteration sweep, which is the whole point of this stage
// (see `strategy.rs`'s module docs).

fn build_ctx(
    hero_combos: Vec<(u8, u8)>,
    villain_combos: Vec<(u8, u8)>,
    preflop_contrib: (f64, f64),
    bet_sizes: (f64, f64, f64),
    max_wagers_per_round: u8,
) -> GameCtx {
    GameCtx {
        hero_combos,
        villain_combos,
        preflop_contrib,
        bet_sizes,
        max_wagers_per_round: max_wagers_per_round as u32,
    }
}

#[pyfunction]
#[pyo3(signature = (flop_board, hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round, avg_strategy, max_sweeps=50))]
#[allow(clippy::too_many_arguments)]
fn actual_value(
    flop_board: [u8; 3],
    hero_combos: Vec<(u8, u8)>,
    villain_combos: Vec<(u8, u8)>,
    preflop_contrib: (f64, f64),
    bet_sizes: (f64, f64, f64),
    max_wagers_per_round: u8,
    avg_strategy: &Bound<'_, PyDict>,
    max_sweeps: u32,
) -> PyResult<(f64, f64)> {
    let _ = max_sweeps; // unused by actual_value itself; kept for a uniform call signature
    let ctx = build_ctx(hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round);
    let avg = AvgStrategy::from_py_dict(avg_strategy)?;
    let r = walk::actual_value(&ctx, &avg, flop_board);
    Ok((r[0], r[1]))
}

#[pyfunction]
#[pyo3(signature = (flop_board, hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round, avg_strategy, player, max_sweeps=50))]
#[allow(clippy::too_many_arguments)]
fn best_response_value(
    flop_board: [u8; 3],
    hero_combos: Vec<(u8, u8)>,
    villain_combos: Vec<(u8, u8)>,
    preflop_contrib: (f64, f64),
    bet_sizes: (f64, f64, f64),
    max_wagers_per_round: u8,
    avg_strategy: &Bound<'_, PyDict>,
    player: u8,
    max_sweeps: u32,
) -> PyResult<f64> {
    let ctx = build_ctx(hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round);
    let avg = AvgStrategy::from_py_dict(avg_strategy)?;
    walk::best_response_value(&ctx, &avg, player, flop_board, max_sweeps).map_err(PyRuntimeError::new_err)
}

#[pyfunction]
#[pyo3(signature = (flop_board, hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round, avg_strategy, max_sweeps=50))]
#[allow(clippy::too_many_arguments)]
fn exploitability_per_player(
    flop_board: [u8; 3],
    hero_combos: Vec<(u8, u8)>,
    villain_combos: Vec<(u8, u8)>,
    preflop_contrib: (f64, f64),
    bet_sizes: (f64, f64, f64),
    max_wagers_per_round: u8,
    avg_strategy: &Bound<'_, PyDict>,
    max_sweeps: u32,
) -> PyResult<(f64, f64)> {
    let ctx = build_ctx(hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round);
    let avg = AvgStrategy::from_py_dict(avg_strategy)?;
    let gaps = walk::exploitability_per_player(&ctx, &avg, flop_board, max_sweeps)
        .map_err(PyRuntimeError::new_err)?;
    Ok((gaps[0], gaps[1]))
}

#[pyfunction]
#[pyo3(signature = (flop_board, hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round, avg_strategy, max_sweeps=50))]
#[allow(clippy::too_many_arguments)]
fn exploitability(
    flop_board: [u8; 3],
    hero_combos: Vec<(u8, u8)>,
    villain_combos: Vec<(u8, u8)>,
    preflop_contrib: (f64, f64),
    bet_sizes: (f64, f64, f64),
    max_wagers_per_round: u8,
    avg_strategy: &Bound<'_, PyDict>,
    max_sweeps: u32,
) -> PyResult<f64> {
    let ctx = build_ctx(hero_combos, villain_combos, preflop_contrib, bet_sizes, max_wagers_per_round);
    let avg = AvgStrategy::from_py_dict(avg_strategy)?;
    walk::exploitability(&ctx, &avg, flop_board, max_sweeps).map_err(PyRuntimeError::new_err)
}

#[pymodule(name = "_native")]
fn native_module(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(ping, m)?)?;
    m.add_function(wrap_pyfunction!(evaluate_5card_native, m)?)?;
    m.add_function(wrap_pyfunction!(evaluate_best_hand_native, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_round_done, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_round_folded, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_legal_for_tokens, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_simulate_round, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_active_round_for, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_information_set_key, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_chance_outcomes, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_is_terminal, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_current_player, m)?)?;
    m.add_function(wrap_pyfunction!(_debug_returns, m)?)?;
    m.add_function(wrap_pyfunction!(actual_value, m)?)?;
    m.add_function(wrap_pyfunction!(best_response_value, m)?)?;
    m.add_function(wrap_pyfunction!(exploitability_per_player, m)?)?;
    m.add_function(wrap_pyfunction!(exploitability, m)?)?;
    Ok(())
}
