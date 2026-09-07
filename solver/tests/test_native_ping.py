def test_native_ping():
    from cfr_solver import _native

    assert _native.ping() == 42
