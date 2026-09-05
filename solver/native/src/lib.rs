//! Stage 8R-1 set up build/CI plumbing only (the no-op `ping()` below).
//! Stage 8R-2 adds the first real logic: a Rust port of the poker hand
//! evaluator in `cards.rs`. The exploitability walk, game rules, and
//! training itself are still pure Python — later stages, not this one.

use pyo3::prelude::*;

mod cards;

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

#[pymodule(name = "_native")]
fn native_module(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(ping, m)?)?;
    m.add_function(wrap_pyfunction!(evaluate_5card_native, m)?)?;
    m.add_function(wrap_pyfunction!(evaluate_best_hand_native, m)?)?;
    Ok(())
}
