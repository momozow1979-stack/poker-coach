"""Generic CFR / CFR+ trainer.

Written entirely against the `Game` interface in `games/game.py` — nothing
here is specific to Kuhn Poker, Leduc Hold'em, or any other game. The player
count is a variable N (0..N-1), not hardcoded to 2, so the same trainer runs
unmodified on 2-player games (Kuhn, Leduc) and N-player self-play games
(3-player Kuhn now; a multiway preflop game in a later phase).

CFR+ (Tammelin et al., 2015, "Solving Heads-up Limit Texas Hold'em") is the
default: regrets are floored at zero after every update (not just when
reading out the current strategy), and the strategy sum is weighted linearly
by iteration number so later, better-converged iterations count more toward
the reported average strategy. Vanilla CFR (Zinkevich et al., 2007) is kept
available via `variant="cfr"` for comparison — regrets are allowed to go
negative in the accumulator (only floored at read-time via regret matching),
and the strategy sum is weighted uniformly by the acting player's own reach
probability.

`train()` walks the *entire* tree every iteration — chance nodes included,
enumerating every outcome. That's fine for Kuhn/Leduc/a single betting round,
but `BENCHMARKS.md`'s `PostflopSubgame` measurement shows exactly where it
breaks: a turn or river chance node alone has ~44/~43 outcomes, so a
connected flop→turn→river tree is dominated by chance-node branching, not by
the (2-3 action) betting decisions. `train_external_sampling()` is the fix
for that specific bottleneck: External-Sampling MCCFR (Lanctot et al., 2009,
"Monte Carlo Sampling for Regret Minimization in Extensive Games") samples
chance outcomes and the *non-traversing* player's actions (one draw each,
instead of enumerating every branch) while still exploring the traversing
player's own actions exhaustively (so its regret updates stay exact, not
sampled). It is proven to converge to the same equilibrium as full CFR, just
with cheaper, noisier iterations — see `docs/ai-prompts.md`-style principle
1 applied to this module: don't claim it converges faster in wall-clock time
without measuring it (`BENCHMARKS.md` records the actual measurement).

## Per-information-set storage (`BENCHMARKS.md`, "情報集合の保存方式")

Widening `PostflopSubgame`'s ranges makes the number of information sets
grow into the tens of millions, at which point the storage this trainer
picks for each one dominates total memory far more than anything about CFR
itself. A per-node Python object holding two `dict[Action, float]`
accumulators (the original design) measured ~720 bytes/information-set,
purely from CPython dict/object overhead — the same 2-3 floats packed into
a flat `array.array` instead cost as little as ~220 bytes/information-set
for the *same numbers, computed the same way* (verified with an
exact-equality regression test, `tests/test_node_storage_regression.py`:
no floating-point operation here is reordered by this storage change, so
results before and after are bit-for-bit identical, not just "close").

Concretely: every information set gets an integer id (`_index[key]`); its
regret/strategy accumulators live in one flat `_regret` / `_strategy`
`array.array('d')` shared across *all* information sets, at
`[id * STRIDE : id * STRIDE + n_actions]`; and its action vocabulary is a
shared, interned tuple (`_ActionSet`, looked up via `_action_set_lookup`) —
this codebase's games only ever have a handful of distinct action
vocabularies (`("x","b")`, `("f","c")`, `("f","c","b")`, ...), so caching
them costs nothing asymptotically while letting tens of millions of
information sets each hold just a 1-byte index into that small cache
instead of allocating their own list. `STRIDE` (currently 3) is a real
constraint, not a magic number: it's the most actions any information set
in this package's games has ever needed, and `_get_node_id` raises loudly
if a future game ever needs more, rather than silently corrupting a
neighboring node's slots.

`array.array`'s own `.extend()` already amortizes growth (same
doubling-style strategy CPython's `list` uses internally), so there is no
hand-rolled capacity/resize logic here to get wrong.

### `_index`: native `NodeIndex` instead of `dict[str, int]`

The three structures above (`_node_action_set_id`/`_regret`/`_strategy`)
account for only ~49 bytes/information-set. Measurement in `BENCHMARKS.md`
found `_index: dict[str, int]` itself costs the other ~147 bytes/entry — a
floor a prior pure-Python optimization pass (bit-packing keys into
integers) already hit and could not get under, because it's CPython's own
per-entry dict bookkeeping plus a separately heap-allocated `str` object per
key, not anything about *what* was stored. `_index` is therefore the one
piece of this module backed by a native (Rust/PyO3) type,
`cfr_solver._native.NodeIndex` (`solver/native/src/lib.rs`): every
information-set key this package's games produce is short and drawn from a
small, bounded character set, so `NodeIndex` stores each key's bytes inline
in a fixed-size buffer inside its Rust `HashMap` — no per-entry heap
allocation — instead of as a separate Python `str` object. Its surface is
intentionally the minimum `_get_node_id`/`average_strategy`/
`num_information_sets` need: `get_or_create(key) -> (id, was_new)`,
`__len__`, and `items()` (which reconstructs the original key strings, but
only once, when `average_strategy()` is called after training — never on
the hot per-node path). This changes nothing about the CFR/CFR+ arithmetic
itself: it is exactly the same kind of storage-only swap the
`array.array` change above was, and is held to the same bit-for-bit
regression bar (`tests/test_node_storage_regression.py`).

## Save/resume (`CFRSolver.save` / `CFRSolver.load`)

`BENCHMARKS.md`'s Stage S2 measurement (32,473,151 information sets, 6.49GB
RSS, ~4 hours) was thrown away the moment its process exited — there was no
way to persist a trained solver and continue it later. `save`/`load` fix
that: they capture every piece of mutable state `train`/`train_external_sampling`
touch and let a *freshly constructed* `CFRSolver` (in a later process, hours
or days later) pick up exactly where the saved one left off, producing
`average_strategy()` output bit-for-bit identical to an uninterrupted run —
same bar as the storage refactors above, verified by
`tests/test_cfr_persistence.py`.

What is NOT saved: `self.game`. Reconstructing a `Game` from its own
constructor arguments is cheap and the caller already knows how to do it
(`PostflopSubgame(flop_board=..., hero_range_notation=..., ...)`), so `load`
takes a freshly-built `Game` instance rather than trying to pickle one —
this also sidesteps ever needing to serialize the game's own internals
(equity caches, etc.), which are no business of this module's persistence
format.

The single easiest way to get this *wrong* is the RNG: `train_external_sampling`
draws from `self._rng` (a `random.Random`), and that stream has already been
partially consumed by the time a save happens. Re-seeding a fresh
`Random(same_seed)` on load would silently replay the *same* "random"
choices the original run already made and moved past — producing a
resumed run that diverges from an uninterrupted one, not one extra bit at
a time but from the very first post-resume sample. The fix is
`random.Random.getstate()`/`.setstate()`, built for exactly this: the full
Mersenne Twister internal state (624 words + position + the Gaussian
spare-value cache) round-trips exactly. `test_cfr_persistence.py` is built
specifically to catch a regression here (it resumes `train_external_sampling`,
which only that path exercises, not `train`).

**Format**: one binary file — a header (variant, iteration counters, RNG
state, the small list of distinct action-vocabulary tuples, a `STRIDE`
sanity value) pickled (chosen over JSON here specifically because
`random.Random.getstate()`'s internal tuple must round-trip with its exact
types and exact float bit-pattern for `gauss_next` — pickle guarantees
both **by construction**; JSON would need extra encode/decode shims for
tuple-vs-list and is not specified to preserve float bit-patterns across
implementations, and this header is tiny regardless of encoding, so
pickle's usual "opaque, larger" downsides don't matter here) — followed by
raw bytes for the three big parallel arrays (`array.tobytes()` — not JSON:
at Stage S2 scale that's 32M+ elements per array, where JSON would be both
far larger on disk and far slower to parse than a direct memory-mapped-
style byte dump) and a compact length-prefixed blob of the information-set
key strings, in insertion-id order.

Rebuilding `_index` (the native `NodeIndex`) deliberately reuses only its
existing `get_or_create`/`items`/`__len__` surface — no new Rust API — by
relying on a property `NodeIndex` already documents and tests
(`ids_are_assigned_densely_in_insertion_order` in `native/src/lib.rs`):
`get_or_create` assigns dense ids `0, 1, 2, ...` strictly in first-seen
order. So `save` calls `items()` once (after training, exactly like
`average_strategy()` already does), sorts by id, and writes out just the
key strings in that order; `load` replays `get_or_create(key)` for those
same keys in that same order into a fresh `NodeIndex`, which is guaranteed
to reassign the identical ids — keeping `_node_action_set_id`/`_regret`/
`_strategy` (restored directly from their saved bytes) correctly aligned
without `NodeIndex` ever needing to serialize itself.

That reuse has a real cost, honestly measured in
`tests/test_cfr_persistence.py`'s scale test rather than assumed: `items()`
allocates one Python `str` per information set (see its own docstring —
it's designed to be called once, off the hot path, not for this to be
free), and `load` then pays a second `get_or_create` Rust call per key on
top of that. At Stage S2's real ~32M-entry scale this is the dominant cost
of `save`/`load` — see that test's recorded timings for how it actually
scales; if it ever becomes a real bottleneck the fix would be a dedicated
bulk export/import on the Rust side (e.g. `NodeIndex.dump_raw()`/
`load_raw()` operating on encoded key bytes directly, skipping the `String`
round-trip and the second hash-and-compare pass `get_or_create` redoes for
keys that are already known-fresh) — deliberately not built here per this
task's brief (reuse the existing native surface unless it's proven
insufficient).
"""

from __future__ import annotations

import pickle
import random
import struct
from array import array
from dataclasses import dataclass, field

from cfr_solver import _native
from cfr_solver.games.game import Action, Game, History

STRIDE = 3  # the most actions any information set in this package needs

_SAVE_FORMAT_MAGIC = b"CFRSOLV1"


def _naive_sum(values: list[float]) -> float:
    """Plain left-to-right float summation — deliberately not the builtin
    `sum()`. CPython 3.12 made `sum()` use Neumaier-compensated summation
    for floats (more accurate, but a *different* rounding than 3.11 and
    earlier's naive addition) — pinning the algorithm here keeps this
    trainer's output independent of which CPython minor version runs it,
    which `tests/test_node_storage_regression.py`'s bit-exact fixture
    (captured once, compared forever) depends on."""
    total = 0.0
    for v in values:
        total += v
    return total


def _write_block(f, data: bytes) -> None:
    """Length-prefixed (8-byte little-endian unsigned) block, so `_read_block`
    knows exactly how many bytes to read back without needing a delimiter
    that might collide with real data."""
    f.write(struct.pack("<Q", len(data)))
    f.write(data)


def _read_block(f) -> bytes:
    (n,) = struct.unpack("<Q", f.read(8))
    return f.read(n)


def _pack_keys(keys: list[str]) -> bytes:
    """Concatenates `keys` into one blob, each prefixed by its UTF-8 byte
    length (4-byte little-endian unsigned) — avoids assuming keys never
    contain any particular delimiter character, and is far cheaper to write
    and re-read at tens-of-millions-of-keys scale than a JSON list of
    strings would be."""
    parts = []
    for key in keys:
        encoded = key.encode("utf-8")
        parts.append(struct.pack("<I", len(encoded)))
        parts.append(encoded)
    return b"".join(parts)


def _unpack_keys(blob: bytes, count: int) -> list[str]:
    keys = []
    offset = 0
    for _ in range(count):
        (length,) = struct.unpack_from("<I", blob, offset)
        offset += 4
        keys.append(blob[offset : offset + length].decode("utf-8"))
        offset += length
    return keys


@dataclass(frozen=True)
class _ActionSet:
    """A shared, immutable action vocabulary. `actions` is never mutated —
    sharing one instance across every information set with the same
    vocabulary is what lets that cost stay flat regardless of how many
    information sets exist."""

    actions: tuple[Action, ...]
    index: dict[Action, int] = field(compare=False)


class CFRSolver:
    """Trains a `Game` via CFR or CFR+ self-play and reports the average strategy."""

    def __init__(
        self, game: Game, variant: str = "cfr_plus", *, random_seed: int | None = None
    ) -> None:
        if variant not in ("cfr", "cfr_plus"):
            raise ValueError(f"unknown variant {variant!r}, expected 'cfr' or 'cfr_plus'")
        self.game = game
        self.variant = variant
        self._index = _native.NodeIndex()
        self._action_set_lookup: dict[tuple[Action, ...], int] = {}
        self._action_sets: list[_ActionSet] = []
        self._node_action_set_id = array("B")
        self._regret = array("d")
        self._strategy = array("d")
        self._iterations_trained = 0
        self._sampled_iterations_trained = 0
        self._rng = random.Random(random_seed)

    def save(self, path: str) -> None:
        """Serializes every piece of state needed to resume training later
        (see the module docstring's "Save/resume" section for the full
        design rationale and format layout) to `path`.

        Does NOT save `self.game` — the caller reconstructs an equivalent
        fresh `Game` and passes it to `load`.
        """
        items = self._index.items()
        items.sort(key=lambda pair: pair[1])  # ascending by id
        keys_in_id_order = [key for key, _nid in items]
        if len(keys_in_id_order) != len(self._index):
            raise RuntimeError(
                "NodeIndex.items() returned a different count than __len__ — "
                "refusing to save a possibly-inconsistent index"
            )

        header = {
            "variant": self.variant,
            "stride": STRIDE,
            "num_nodes": len(keys_in_id_order),
            "iterations_trained": self._iterations_trained,
            "sampled_iterations_trained": self._sampled_iterations_trained,
            "rng_state": self._rng.getstate(),
            "action_sets": [list(aset.actions) for aset in self._action_sets],
        }
        header_bytes = pickle.dumps(header, protocol=pickle.HIGHEST_PROTOCOL)

        with open(path, "wb") as f:
            f.write(_SAVE_FORMAT_MAGIC)
            _write_block(f, header_bytes)
            _write_block(f, self._node_action_set_id.tobytes())
            _write_block(f, self._regret.tobytes())
            _write_block(f, self._strategy.tobytes())
            _write_block(f, _pack_keys(keys_in_id_order))

    @classmethod
    def load(cls, path: str, game: Game) -> "CFRSolver":
        """Reconstructs a `CFRSolver` from a file written by `save`, bound to
        the caller-provided (freshly built) `game`.

        Resuming training on the result (`train`/`train_external_sampling`)
        and reading `average_strategy()` produces output bit-for-bit
        identical to a single uninterrupted run for the same total
        iteration count — see `tests/test_cfr_persistence.py`. This
        includes exactly restoring `random.Random`'s internal state (not
        re-seeding), which is what makes `train_external_sampling` resume
        safely; see the module docstring for why that specific detail is
        easy to get wrong.
        """
        with open(path, "rb") as f:
            magic = f.read(len(_SAVE_FORMAT_MAGIC))
            if magic != _SAVE_FORMAT_MAGIC:
                raise ValueError(f"{path!r} is not a CFRSolver save file (bad magic bytes)")
            header = pickle.loads(_read_block(f))
            node_action_set_id_bytes = _read_block(f)
            regret_bytes = _read_block(f)
            strategy_bytes = _read_block(f)
            keys_blob = _read_block(f)

        if header["stride"] != STRIDE:
            raise ValueError(
                f"save file was written with STRIDE={header['stride']}, but this build of "
                f"cfr.py uses STRIDE={STRIDE} — incompatible, refusing to load"
            )

        solver = cls(game, variant=header["variant"])
        solver._rng.setstate(header["rng_state"])
        solver._iterations_trained = header["iterations_trained"]
        solver._sampled_iterations_trained = header["sampled_iterations_trained"]

        # Rebuild the shared action-vocabulary cache in its original order —
        # `_get_action_set_id` appends to an initially-empty
        # `_action_sets`/`_action_set_lookup`, so replaying the saved list
        # in order reproduces the original ids exactly (same reasoning as
        # the NodeIndex replay below).
        for actions in header["action_sets"]:
            solver._get_action_set_id(actions)

        # Rebuild `_index` by replaying `get_or_create` in the exact
        # original id-assignment order (see module docstring). This
        # reproduces identical ids without any new Rust API, so the arrays
        # below (restored verbatim from their saved bytes) stay correctly
        # aligned by node id.
        keys_in_id_order = _unpack_keys(keys_blob, header["num_nodes"])
        for key in keys_in_id_order:
            solver._index.get_or_create(key)
        if len(solver._index) != header["num_nodes"]:
            raise RuntimeError(
                f"replaying saved keys produced {len(solver._index)} node(s), expected "
                f"{header['num_nodes']} — save file is corrupt or keys collided unexpectedly"
            )

        solver._node_action_set_id = array("B")
        solver._node_action_set_id.frombytes(node_action_set_id_bytes)
        solver._regret = array("d")
        solver._regret.frombytes(regret_bytes)
        solver._strategy = array("d")
        solver._strategy.frombytes(strategy_bytes)

        return solver

    def _get_action_set_id(self, actions: list[Action]) -> int:
        canon = tuple(actions)
        aset_id = self._action_set_lookup.get(canon)
        if aset_id is not None:
            return aset_id
        if len(canon) > STRIDE:
            raise RuntimeError(
                f"action set {canon!r} has {len(canon)} actions, exceeding STRIDE={STRIDE} "
                "— widen STRIDE in cfr.py for a game that legitimately needs more"
            )
        aset_id = len(self._action_sets)
        self._action_sets.append(
            _ActionSet(actions=canon, index={a: i for i, a in enumerate(canon)})
        )
        self._action_set_lookup[canon] = aset_id
        return aset_id

    def _get_node_id(self, key: str, actions: list[Action]) -> int:
        nid, is_new = self._index.get_or_create(key)
        if not is_new:
            return nid
        self._node_action_set_id.append(self._get_action_set_id(actions))
        self._regret.extend([0.0] * STRIDE)
        self._strategy.extend([0.0] * STRIDE)
        return nid

    def _action_set_for(self, nid: int) -> _ActionSet:
        return self._action_sets[self._node_action_set_id[nid]]

    def _current_strategy(self, nid: int) -> dict[Action, float]:
        """Regret matching: strategy proportional to positive regret.

        Uniform if every action has non-positive regret. This same
        computation is correct for both variants — under CFR+ the
        accumulator is already floored at zero by the update rule, so
        `max(0, r)` here is a no-op; under vanilla CFR the accumulator can
        go negative, and this is exactly where the projection back onto
        positive regret happens.
        """
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        n = len(aset.actions)
        positive = [max(0.0, self._regret[base + i]) for i in range(n)]
        total = _naive_sum(positive)
        if total > 0:
            return {a: v / total for a, v in zip(aset.actions, positive)}
        return {a: 1.0 / n for a in aset.actions}

    def _average_strategy_for(self, nid: int) -> dict[Action, float]:
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        n = len(aset.actions)
        values = [self._strategy[base + i] for i in range(n)]
        total = _naive_sum(values)
        if total > 0:
            return {a: v / total for a, v in zip(aset.actions, values)}
        return {a: 1.0 / n for a in aset.actions}

    def train(self, iterations: int) -> None:
        num_players = self.game.num_players
        for i in range(1, iterations + 1):
            iteration = self._iterations_trained + i
            self._cfr(
                self.game.new_initial_history(),
                reach_probs=[1.0] * num_players,
                iteration=iteration,
            )
        self._iterations_trained += iterations

    def _cfr(self, history: History, reach_probs: list[float], iteration: int) -> list[float]:
        game = self.game

        if game.is_terminal(history):
            return list(game.returns(history))

        if game.is_chance_node(history):
            num_players = game.num_players
            total = [0.0] * num_players
            for action, prob in game.chance_outcomes(history):
                child_util = self._cfr(game.next_history(history, action), reach_probs, iteration)
                for p in range(num_players):
                    total[p] += prob * child_util[p]
            return total

        player = game.current_player(history)
        actions = game.legal_actions(history)
        key = game.information_set_key(history, player)
        nid = self._get_node_id(key, actions)
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        strategy = self._current_strategy(nid)

        num_players = game.num_players
        action_utils: dict[Action, list[float]] = {}
        node_util = [0.0] * num_players
        for action in actions:
            child_reach = list(reach_probs)
            child_reach[player] *= strategy[action]
            util = self._cfr(game.next_history(history, action), child_reach, iteration)
            action_utils[action] = util
            for p in range(num_players):
                node_util[p] += strategy[action] * util[p]

        # Counterfactual reach: probability of reaching this history under
        # every OTHER player's (and chance's, already folded in above)
        # strategy, excluding the acting player's own contribution.
        cf_reach = 1.0
        for p in range(num_players):
            if p != player:
                cf_reach *= reach_probs[p]

        for action in actions:
            slot = base + aset.index[action]
            regret = action_utils[action][player] - node_util[player]
            updated = self._regret[slot] + cf_reach * regret
            if self.variant == "cfr_plus":
                updated = max(0.0, updated)
            self._regret[slot] = updated

        own_reach = reach_probs[player]
        weight = own_reach * (iteration if self.variant == "cfr_plus" else 1.0)
        for action in actions:
            slot = base + aset.index[action]
            self._strategy[slot] += weight * strategy[action]

        return node_util

    def train_external_sampling(self, iterations: int) -> None:
        """External-Sampling MCCFR — one traversal per player per iteration.

        Shares the same flat storage (and therefore the same
        `average_strategy()`) as `train()`, so the two can even be mixed on
        the same solver instance, though that isn't a configuration this
        package currently tests.
        """
        num_players = self.game.num_players
        for i in range(1, iterations + 1):
            iteration = self._sampled_iterations_trained + i
            for traverser in range(num_players):
                self._external_sampling(self.game.new_initial_history(), traverser, iteration)
        self._sampled_iterations_trained += iterations

    def _external_sampling(self, history: History, traverser: int, iteration: int) -> list[float]:
        game = self.game

        if game.is_terminal(history):
            return list(game.returns(history))

        if game.is_chance_node(history):
            outcomes = game.chance_outcomes(history)
            actions = [a for a, _p in outcomes]
            weights = [p for _a, p in outcomes]
            sampled = self._rng.choices(actions, weights=weights, k=1)[0]
            return self._external_sampling(game.next_history(history, sampled), traverser, iteration)

        num_players = game.num_players
        player = game.current_player(history)
        actions = game.legal_actions(history)
        key = game.information_set_key(history, player)
        nid = self._get_node_id(key, actions)
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        strategy = self._current_strategy(nid)

        if player == traverser:
            # Traverser's own decision: explored exhaustively, exactly like
            # full CFR, so its regret update is exact — only the OPPONENT
            # and CHANCE branches below are sampled. No counterfactual-reach
            # weighting is needed here (unlike `_cfr`): the opponent/chance
            # sampling already makes this an unbiased estimator of the true
            # counterfactual value on its own (Lanctot et al., 2009).
            action_utils: dict[Action, list[float]] = {}
            node_util = [0.0] * num_players
            for action in actions:
                util = self._external_sampling(
                    game.next_history(history, action), traverser, iteration
                )
                action_utils[action] = util
                for p in range(num_players):
                    node_util[p] += strategy[action] * util[p]

            for action in actions:
                slot = base + aset.index[action]
                regret = action_utils[action][traverser] - node_util[traverser]
                updated = self._regret[slot] + regret
                if self.variant == "cfr_plus":
                    updated = max(0.0, updated)
                self._regret[slot] = updated

            return node_util

        # A non-traverser's decision: record the full mixed strategy into
        # strategy_sum (as usual — this is what makes the average strategy
        # converge for THIS player once it's their turn to be the
        # traverser), but only recurse into one action sampled from it.
        weight = iteration if self.variant == "cfr_plus" else 1.0
        for action in actions:
            slot = base + aset.index[action]
            self._strategy[slot] += weight * strategy[action]

        sampled_action = self._rng.choices(actions, weights=[strategy[a] for a in actions], k=1)[0]
        return self._external_sampling(
            game.next_history(history, sampled_action), traverser, iteration
        )

    def average_strategy(self) -> dict[str, dict[Action, float]]:
        """The (near-)equilibrium strategy: `{information_set_key: {action: probability}}`."""
        return {key: self._average_strategy_for(nid) for key, nid in self._index.items()}

    @property
    def num_information_sets(self) -> int:
        return len(self._index)
