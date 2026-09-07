//! Rust port of `cfr_solver.poker.cards` (Stage 8R-2). Same two-table
//! "Cactus Kev"-style approach as the Python original — see that module's
//! docstring for the full rationale. Cards are plain `u8`s 0..51, exactly
//! like Python's plain `int`s: `rank = card / 4` (0=deuce..12=ace),
//! `suit = card % 4`.
//!
//! Python's evaluator returns a comparison *tuple* and only ever relies on
//! its relative order (`<`/`>`/`sorted()` — see `test_poker_cards.py`'s
//! module docstring), never the concrete values. Here we instead pack a
//! hand's rank into a single `u32`, laid out so that ordinary integer
//! comparison reproduces exactly the same order as Python's tuple
//! comparison:
//!
//!   bits [23:20] = category (0=high card .. 8=straight flush, matches
//!                  `cfr_solver.poker.cards`'s `HIGH_CARD..STRAIGHT_FLUSH`)
//!   bits [19:16] = kicker 0 (most significant)
//!   bits [15:12] = kicker 1
//!   bits [11:8]  = kicker 2
//!   bits [7:4]   = kicker 3
//!   bits [3:0]   = kicker 4 (least significant)
//!
//! Every rank fits in 4 bits (0..12), and every category uses a *fixed*
//! number of kicker slots (e.g. always 2 for quads: quad-rank, kicker —
//! never more, never fewer), so two packed hands of the same category are
//! only ever compared kicker-by-kicker in the same left-to-right priority
//! order Python's tuple comparison uses; unused trailing kicker slots are
//! zero-filled and never participate in a cross-category comparison
//! (category already differs at the top nibble in that case, exactly as
//! the first tuple element decides everything in Python once categories
//! differ). This is the one place a bit-layout mistake could silently
//! invert two hands' relative order, so `evaluate_5card`'s exhaustive
//! cross-check against Python (`tests/test_native_cards.py`) is the real
//! proof, backed by the pure-Rust spot checks below.

use std::sync::OnceLock;

pub const HIGH_CARD: u8 = 0;
pub const ONE_PAIR: u8 = 1;
pub const TWO_PAIR: u8 = 2;
pub const TRIPS: u8 = 3;
pub const STRAIGHT: u8 = 4;
pub const FLUSH: u8 = 5;
pub const FULL_HOUSE: u8 = 6;
pub const QUADS: u8 = 7;
pub const STRAIGHT_FLUSH: u8 = 8;

/// One prime per rank (2..A), identical to Python's `_RANK_PRIME`. The
/// product of 5 ranks' primes uniquely identifies that multiset of ranks
/// (unique prime factorization), so it doubles as a perfect-hash key for
/// "which ranks, with which multiplicity".
const RANK_PRIME: [u64; 13] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41];

#[inline]
fn rank_of(card: u8) -> u8 {
    card / 4
}

#[inline]
fn suit_of(card: u8) -> u8 {
    card % 4
}

/// Pack a category + up to 5 kickers (most-significant first) into the
/// comparison-order-preserving `u32` described in the module docs. Missing
/// trailing kickers (a category needs fewer than 5) are zero-filled.
#[inline]
fn pack(category: u8, kickers: &[u8]) -> u32 {
    debug_assert!(kickers.len() <= 5);
    let mut v: u32 = (category as u32) << 20;
    for i in 0..5 {
        let k = *kickers.get(i).unwrap_or(&0) as u32;
        v |= k << (16 - 4 * i);
    }
    v
}

/// 13-bit rank-presence bitmask -> straight high rank, for all 10 real
/// straights (6-high through broadway/ace-high) plus the wheel. Indexed
/// directly by the bitmask (0..=8191); `None` means "not a straight".
type StraightTable = [Option<u8>; 8192];

fn build_straight_table() -> StraightTable {
    let mut table: StraightTable = [None; 8192];
    for top in 4u8..13 {
        // top=4 -> 6-high (ranks 0..=4), top=12 -> broadway (ranks 8..=12)
        let mut bitmask: u32 = 0;
        for r in (top - 4)..=top {
            bitmask |= 1 << r;
        }
        table[bitmask as usize] = Some(top);
    }
    let wheel_bitmask: u32 = (1 << 12) | (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3);
    table[wheel_bitmask as usize] = Some(3); // A-2-3-4-5 ranks as 5-high, not ace-high
    table
}

/// Prime product of a 5-rank multiset -> fully packed `u32` hand rank
/// (category + kickers already combined via `pack`), for every multiset
/// that contains at least one repeated rank. A 5-distinct-rank hand can
/// never reach this table (handled separately in `evaluate_5card`, exactly
/// as in the Python original).
fn build_pattern_table() -> std::collections::HashMap<u64, u32> {
    let mut table = std::collections::HashMap::new();
    // Enumerate combinations_with_replacement(range(13), 5) via 5 nested
    // non-decreasing loops (equivalent to itertools.combinations_with_replacement).
    for a in 0u8..13 {
        for b in a..13 {
            for c in b..13 {
                for d in c..13 {
                    for e in d..13 {
                        let ranks = [a, b, c, d, e];
                        let mut counts = [0u8; 13];
                        for &r in &ranks {
                            counts[r as usize] += 1;
                        }
                        let distinct = counts.iter().filter(|&&n| n > 0).count();
                        if distinct == 5 {
                            continue; // all distinct -- not this table's job
                        }
                        // by_count_then_rank: (rank, count) sorted by (-count, -rank)
                        let mut by_count_then_rank: Vec<(u8, u8)> = (0u8..13)
                            .filter(|&r| counts[r as usize] > 0)
                            .map(|r| (r, counts[r as usize]))
                            .collect();
                        by_count_then_rank.sort_by(|x, y| {
                            y.1.cmp(&x.1).then(y.0.cmp(&x.0))
                        });
                        let count_pattern: Vec<u8> =
                            by_count_then_rank.iter().map(|&(_, cnt)| cnt).collect();
                        let ordered_ranks: Vec<u8> =
                            by_count_then_rank.iter().map(|&(r, _)| r).collect();
                        let category = match count_pattern.as_slice() {
                            [4, 1] => QUADS,
                            [3, 2] => FULL_HOUSE,
                            [3, 1, 1] => TRIPS,
                            [2, 2, 1] => TWO_PAIR,
                            [2, 1, 1, 1] => ONE_PAIR,
                            // A pattern like [5] (5 of the same rank) cannot occur
                            // in a real hand (each rank has only 4 suits), but the
                            // nested-loop generation doesn't know that; skip it.
                            _ => continue,
                        };
                        let mut product: u64 = 1;
                        for &r in &ranks {
                            product *= RANK_PRIME[r as usize];
                        }
                        table.insert(product, pack(category, &ordered_ranks));
                    }
                }
            }
        }
    }
    table
}

static STRAIGHT_TABLE: OnceLock<StraightTable> = OnceLock::new();
static PATTERN_TABLE: OnceLock<std::collections::HashMap<u64, u32>> = OnceLock::new();

fn straight_table() -> &'static StraightTable {
    STRAIGHT_TABLE.get_or_init(build_straight_table)
}

fn pattern_table() -> &'static std::collections::HashMap<u64, u32> {
    PATTERN_TABLE.get_or_init(build_pattern_table)
}

/// Rank a 5-card hand. Higher `u32` == better hand (plain integer
/// comparison) -- see the module docs for the bit layout and why it
/// reproduces Python's tuple-comparison order exactly.
pub fn evaluate_5card(cards: [u8; 5]) -> u32 {
    let ranks: [u8; 5] = [
        rank_of(cards[0]),
        rank_of(cards[1]),
        rank_of(cards[2]),
        rank_of(cards[3]),
        rank_of(cards[4]),
    ];
    let suit0 = suit_of(cards[0]);
    let is_flush = cards[1..].iter().all(|&c| suit_of(c) == suit0);

    let mut rank_bits: u32 = 0;
    for &r in &ranks {
        rank_bits |= 1 << r;
    }

    if rank_bits.count_ones() == 5 {
        // 5 distinct ranks: no pair/trips/etc. is possible, only straight
        // and/or flush (independently) or plain high card.
        let straight_high = straight_table()[rank_bits as usize];
        let mut ordered_ranks = ranks;
        ordered_ranks.sort_unstable_by(|a, b| b.cmp(a)); // descending
        if let Some(high) = straight_high {
            if is_flush {
                return pack(STRAIGHT_FLUSH, &[high]);
            }
        }
        if is_flush {
            return pack(FLUSH, &ordered_ranks);
        }
        if let Some(high) = straight_high {
            return pack(STRAIGHT, &[high]);
        }
        return pack(HIGH_CARD, &ordered_ranks);
    }

    // A rank repeats, so (as in real poker) this hand cannot be a flush
    // (two cards of the same rank always have different suits) or a
    // straight (which needs 5 distinct ranks) -- look up the pattern
    // directly. The table already stores the fully packed value.
    let mut product: u64 = 1;
    for &r in &ranks {
        product *= RANK_PRIME[r as usize];
    }
    *pattern_table()
        .get(&product)
        .unwrap_or_else(|| panic!("no pattern entry for product {product} (ranks {ranks:?})"))
}

/// Best 5-card hand out of 5, 6, or 7 cards (hole cards + a partial or
/// complete board). Degenerates to `evaluate_5card` when given exactly 5.
pub fn evaluate_best_hand(cards: &[u8]) -> u32 {
    match cards.len() {
        5 => evaluate_5card([cards[0], cards[1], cards[2], cards[3], cards[4]]),
        6 | 7 => {
            let mut best = 0u32;
            // All 5-card subsets of `cards`, same combinatorial approach as
            // Python's `itertools.combinations(cards, 5)`.
            let n = cards.len();
            let mut idx = [0usize; 5];
            for a in 0..n {
                idx[0] = a;
                for b in (a + 1)..n {
                    idx[1] = b;
                    for c in (b + 1)..n {
                        idx[2] = c;
                        for d in (c + 1)..n {
                            idx[3] = d;
                            for e in (d + 1)..n {
                                idx[4] = e;
                                let five = [
                                    cards[idx[0]],
                                    cards[idx[1]],
                                    cards[idx[2]],
                                    cards[idx[3]],
                                    cards[idx[4]],
                                ];
                                let v = evaluate_5card(five);
                                if v > best {
                                    best = v;
                                }
                            }
                        }
                    }
                }
            }
            best
        }
        n => panic!("evaluate_best_hand expects 5-7 cards, got {n}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hand(cards: [u8; 5]) -> u32 {
        evaluate_5card(cards)
    }

    fn card(rank_symbol: char, suit_symbol: char) -> u8 {
        let rank = "23456789TJQKA".find(rank_symbol).unwrap() as u8;
        let suit = "shdc".find(suit_symbol).unwrap() as u8;
        rank * 4 + suit
    }

    #[test]
    fn hand_categories_rank_in_the_correct_order() {
        let hands: [[u8; 5]; 9] = [
            [
                card('A', 's'),
                card('K', 's'),
                card('Q', 's'),
                card('J', 's'),
                card('T', 's'),
            ], // straight flush (royal)
            [
                card('A', 'h'),
                card('A', 's'),
                card('A', 'd'),
                card('A', 'c'),
                card('2', 's'),
            ], // quads
            [
                card('A', 'h'),
                card('A', 's'),
                card('A', 'd'),
                card('2', 's'),
                card('2', 'h'),
            ], // full house
            [
                card('A', 'h'),
                card('K', 'h'),
                card('9', 'h'),
                card('5', 'h'),
                card('2', 'h'),
            ], // flush
            [
                card('9', 'h'),
                card('8', 's'),
                card('7', 'd'),
                card('6', 'c'),
                card('5', 'h'),
            ], // straight
            [
                card('A', 'h'),
                card('A', 's'),
                card('A', 'd'),
                card('5', 'c'),
                card('2', 'h'),
            ], // trips
            [
                card('A', 'h'),
                card('A', 's'),
                card('K', 'd'),
                card('K', 'c'),
                card('2', 'h'),
            ], // two pair
            [
                card('A', 'h'),
                card('A', 's'),
                card('K', 'd'),
                card('Q', 'c'),
                card('2', 'h'),
            ], // one pair
            [
                card('A', 'h'),
                card('K', 's'),
                card('Q', 'd'),
                card('J', 'c'),
                card('9', 'h'),
            ], // high card
        ];
        let values: Vec<u32> = hands.iter().map(|h| hand(*h)).collect();
        let mut sorted_desc = values.clone();
        sorted_desc.sort_unstable_by(|a, b| b.cmp(a));
        assert_eq!(values, sorted_desc);
    }

    #[test]
    fn wheel_straight_ranks_as_five_high() {
        let wheel = hand([card('5', 'h'), card('4', 's'), card('3', 'd'), card('2', 'c'), card('A', 'h')]);
        let six_high = hand([card('6', 'h'), card('5', 's'), card('4', 'd'), card('3', 'c'), card('2', 'h')]);
        assert!(wheel < six_high, "A-2-3-4-5 must rank as a 5-high straight, not an ace-high hand");
    }

    #[test]
    fn wheel_straight_flush_beats_quads() {
        let wheel_flush = hand([card('5', 'h'), card('4', 'h'), card('3', 'h'), card('2', 'h'), card('A', 'h')]);
        let quads = hand([card('K', 'h'), card('K', 's'), card('K', 'd'), card('K', 'c'), card('2', 'h')]);
        assert!(wheel_flush > quads);
    }

    #[test]
    fn best_hand_degenerates_to_5card_for_five_cards() {
        let five = [card('A', 'h'), card('K', 'h'), card('9', 'h'), card('5', 'h'), card('2', 'h')];
        assert_eq!(evaluate_best_hand(&five), evaluate_5card(five));
    }
}
