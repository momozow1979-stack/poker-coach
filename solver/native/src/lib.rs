//! Stage 8R-1: build/CI plumbing only. No card-evaluation or exploitability
//! logic lives here yet — that's later stages (8R-2+). This module exposes a
//! single no-op `ping()` function so the Python <-> Rust build pipeline
//! (maturin, PyO3, CI) can be proven end-to-end before any real logic is
//! ported.

use pyo3::prelude::*;

/// Trivial no-op used to verify the native extension loads and runs.
#[pyfunction]
fn ping() -> i64 {
    42
}

#[pymodule(name = "_native")]
fn native_module(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(ping, m)?)?;
    Ok(())
}
