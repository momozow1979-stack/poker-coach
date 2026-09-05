//! Rust port of `PostflopSubgame`'s game-rule logic
//! (`cfr_solver/games/postflop_subgame.py`, Stage 8R-3). NOT the
//! exploitability walk, `avg_strategy` handling, or training -- those stay
//! pure Python (later stages). Every function here is a direct, line-by-line
//! port of the corresponding Python function; see that module for the
//! rationale behind each piece (its module docstring explains why these
//! particular helpers exist and were made `lru_cache`-friendly pure
//! functions in Python -- ported to Rust, the same "small pure function of
//! bounded-cardinality input" shape just means no cache is needed at all,
//! since a native call is already cheaper than a Python dict lookup).
//!
//! Reachable token-string length bound: each street starts empty and ends
//! the moment the last two characters are `"xx"` or the last character is
//! `"c"`/`"f"`. Before that, every character is one of `"x"` (only as the
//! very first character), `"b"` (at most `max_wagers_per_round` times, by
//! `_legal_for_tokens`'s `count("b") < max_wagers` gate), `"c"`, or `"f"`
//! (both of which end the round immediately). So a reachable token string is
//! at most `max_wagers_per_round + 1` characters long (`max_wagers_per_round`
//! bets/raises, each of which -- other than the last -- must be followed by
//! a call to keep betting, plus one final call/fold) -- comfortably under
//! `TokenBuf`'s 8-byte capacity for any realistic `max_wagers_per_round`.

use crate::cards;
use crate::history::{BoardBuf, Combo, History, TokenBuf};

// -- module-level pure helpers (mirrors of the `@lru_cache` functions) -----

pub fn round_done(tokens: &TokenBuf) -> bool {
    tokens.as_str() == "xx" || matches!(tokens.last(), Some(b'c') | Some(b'f'))
}

pub fn round_folded(tokens: &TokenBuf) -> bool {
    matches!(tokens.last(), Some(b'f'))
}

/// Legal action bytes for the given token string, or `Err(message)` on a
/// completed round -- mirrors Python's `ValueError` (`legal_actions` is only
/// ever called by callers who already know the round is still active, via
/// `_active_round` returning non-`None` -- see that function's Python
/// docstring -- so this contract is documented, not load-bearing).
pub fn legal_for_tokens(tokens: &TokenBuf, max_wagers: u32) -> Result<Vec<u8>, String> {
    if tokens.is_empty() || tokens.last() == Some(b'x') {
        return Ok(vec![b'x', b'b']);
    }
    if tokens.last() == Some(b'b') {
        if (tokens.count(b'b') as u32) < max_wagers {
            return Ok(vec![b'f', b'c', b'b']);
        }
        return Ok(vec![b'f', b'c']);
    }
    Err(format!("legal_actions called on a completed round: {:?}", tokens.as_str()))
}

/// Replays `tokens` char by char, returning each player's chip contribution
/// for the street and the folder (if any). A simple sequential accumulation
/// -- no float reassociation risk versus the Python original.
pub fn simulate_round(tokens: &TokenBuf, bet_size: f64) -> ((f64, f64), Option<u8>) {
    let mut contrib = [0.0f64, 0.0f64];
    let mut level = 0.0f64;
    let mut actor: u8 = 0;
    for &ch in &tokens.bytes[..tokens.len as usize] {
        match ch {
            b'b' => {
                level += bet_size;
                contrib[actor as usize] = level;
            }
            b'c' => {
                contrib[actor as usize] = level;
            }
            b'f' => {
                return ((contrib[0], contrib[1]), Some(actor));
            }
            _ => {}
        }
        actor = 1 - actor;
    }
    ((contrib[0], contrib[1]), None)
}

/// (tokens, bet_size, street_index) for whichever round is currently being
/// bet, or `None` if we're between streets / at showdown.
pub fn active_round_for(
    board: &BoardBuf,
    flop_a: &TokenBuf,
    turn_a: &TokenBuf,
    river_a: &TokenBuf,
    bet_sizes: (f64, f64, f64),
) -> Option<(TokenBuf, f64, u8)> {
    match board.len {
        3 => {
            if !round_done(flop_a) {
                Some((*flop_a, bet_sizes.0, 0))
            } else {
                None
            }
        }
        4 => {
            if !round_done(turn_a) {
                Some((*turn_a, bet_sizes.1, 1))
            } else {
                None
            }
        }
        _ => {
            if !round_done(river_a) {
                Some((*river_a, bet_sizes.2, 2))
            } else {
                None
            }
        }
    }
}

/// 2-zero-padded-digits-per-card encoding (card ids 0..51, so 2 digits
/// always suffice) -- mirrors `_card_digits`.
fn push_card_digits(out: &mut String, cards: &[u8]) {
    for &c in cards {
        assert!(c <= 51, "card id {c} out of range 0..51 -- key encoding assumes 2 digits");
        out.push_str(&format!("{c:02}"));
    }
}

/// Byte-identical port of `PostflopSubgame.information_set_key`: exactly
/// `f"{combo_digits}{board_digits}|{flop_a}|{turn_a}|{river_a}"` where
/// `combo_digits`/`board_digits` are the 2-digit-per-card encoding of the
/// acting player's own combo and the board only. The `|` separators are
/// load-bearing (prevent action-string concatenation collisions across
/// streets) -- see the Python docstring.
pub fn information_set_key(
    own_combo: Combo,
    board: &BoardBuf,
    flop_a: &TokenBuf,
    turn_a: &TokenBuf,
    river_a: &TokenBuf,
) -> String {
    let mut s = String::with_capacity(
        4 + 2 * board.len as usize + 3 + flop_a.len as usize + turn_a.len as usize + river_a.len as usize,
    );
    push_card_digits(&mut s, &[own_combo.0, own_combo.1]);
    push_card_digits(&mut s, board.as_slice());
    s.push('|');
    s.push_str(flop_a.as_str());
    s.push('|');
    s.push_str(turn_a.as_str());
    s.push('|');
    s.push_str(river_a.as_str());
    s
}

fn payoffs_from_fold(total_contrib: [f64; 2], folder: u8) -> [f64; 2] {
    let pot = total_contrib[0] + total_contrib[1];
    let winner = 1 - folder;
    let mut result = [0.0f64; 2];
    result[winner as usize] = pot - total_contrib[winner as usize];
    result[folder as usize] = -total_contrib[folder as usize];
    result
}

// -- Game-interface-shaped functions ----------------------------------------

// `is_chance_node`, `next_history`, and `legal_actions` are ported here per
// Stage 8R-3's spec (a full port of the rules, not just what the debug
// bindings happen to exercise directly today), but no debug binding calls
// them yet -- `is_chance_node`/`next_history` aren't in the spec's debug-
// binding list, and `legal_actions` is exercised only indirectly (via
// `legal_for_tokens`, which every debug binding path actually goes
// through). Left `#[allow(dead_code)]` rather than deleted since later
// stages (the exploitability walk) are expected to call these directly.
#[allow(dead_code)]
pub fn is_chance_node(h: &History) -> bool {
    if h.hero_combo.is_none() || h.villain_combo.is_none() {
        return true;
    }
    if h.board.len == 3 && round_done(&h.flop_a) && !round_folded(&h.flop_a) {
        return true;
    }
    if h.board.len == 4 && round_done(&h.turn_a) && !round_folded(&h.turn_a) {
        return true;
    }
    false
}

/// Every possible chance outcome and its probability, in the SAME order a
/// DFS over Python's `chance_outcomes` would produce (later stages'
/// parallelization depends on this -- see the module docs above). Outcomes
/// are returned as `(action_string, probability)` pairs exactly like
/// Python's `chance_outcomes` (the action string is just the stringified
/// combo index or card id, matching `str(i)`/`str(c)`).
pub fn chance_outcomes(
    hero_combos: &[Combo],
    villain_combos: &[Combo],
    hero_combo: Option<Combo>,
    villain_combo: Option<Combo>,
    board: &BoardBuf,
) -> Result<Vec<(String, f64)>, String> {
    if hero_combo.is_none() {
        let n = hero_combos.len();
        let p = 1.0 / n as f64;
        return Ok((0..n).map(|i| (i.to_string(), p)).collect());
    }
    let hero = hero_combo.unwrap();
    if villain_combo.is_none() {
        let live: Vec<usize> = villain_combos
            .iter()
            .enumerate()
            .filter(|(_, c)| c.0 != hero.0 && c.0 != hero.1 && c.1 != hero.0 && c.1 != hero.1)
            .map(|(i, _)| i)
            .collect();
        if live.is_empty() {
            return Err("every villain combo clashes with hero's dealt combo".to_string());
        }
        let p = 1.0 / live.len() as f64;
        return Ok(live.into_iter().map(|i| (i.to_string(), p)).collect());
    }
    let villain = villain_combo.unwrap();
    // turn or river card: uniform over DECK (ascending 0..52) minus every
    // card already used (board + hero combo + villain combo).
    let mut used = [false; 52];
    for &c in board.as_slice() {
        used[c as usize] = true;
    }
    used[hero.0 as usize] = true;
    used[hero.1 as usize] = true;
    used[villain.0 as usize] = true;
    used[villain.1 as usize] = true;
    let remaining: Vec<u8> = (0u8..52).filter(|&c| !used[c as usize]).collect();
    let p = 1.0 / remaining.len() as f64;
    Ok(remaining.into_iter().map(|c| (c.to_string(), p)).collect())
}

/// `action` here is the raw action string exactly as `Game::next_history`
/// receives it: a stringified combo index for the two chance-deal cases, a
/// stringified card id for the turn/river deal, or a single betting-action
/// character (`"x"`/`"b"`/`"c"`/`"f"`) otherwise.
#[allow(dead_code)]
pub fn next_history(h: &History, hero_combos: &[Combo], villain_combos: &[Combo], action: &str) -> History {
    if h.hero_combo.is_none() {
        let idx: usize = action.parse().expect("chance action must be a combo index");
        return History { hero_combo: Some(hero_combos[idx]), ..*h };
    }
    if h.villain_combo.is_none() {
        let idx: usize = action.parse().expect("chance action must be a combo index");
        return History { villain_combo: Some(villain_combos[idx]), ..*h };
    }
    if h.board.len == 3 && round_done(&h.flop_a) && !round_folded(&h.flop_a) {
        let card: u8 = action.parse().expect("chance action must be a card id");
        return History { board: h.board.pushed(card), ..*h };
    }
    if h.board.len == 4 && round_done(&h.turn_a) && !round_folded(&h.turn_a) {
        let card: u8 = action.parse().expect("chance action must be a card id");
        return History { board: h.board.pushed(card), ..*h };
    }
    assert_eq!(action.len(), 1, "betting action must be a single character: {action:?}");
    let ch = action.as_bytes()[0];
    if h.board.len == 3 {
        History { flop_a: h.flop_a.pushed(ch), ..*h }
    } else if h.board.len == 4 {
        History { turn_a: h.turn_a.pushed(ch), ..*h }
    } else {
        History { river_a: h.river_a.pushed(ch), ..*h }
    }
}

pub fn is_terminal(h: &History) -> bool {
    if h.hero_combo.is_none() || h.villain_combo.is_none() {
        return false;
    }
    match h.board.len {
        3 => round_done(&h.flop_a) && round_folded(&h.flop_a),
        4 => round_done(&h.turn_a) && round_folded(&h.turn_a),
        _ => round_done(&h.river_a),
    }
}

pub fn current_player(h: &History, bet_sizes: (f64, f64, f64)) -> u8 {
    let (tokens, _bet_size, _street) =
        active_round_for(&h.board, &h.flop_a, &h.turn_a, &h.river_a, bet_sizes)
            .expect("current_player called on a history with no active round");
    tokens.len % 2
}

#[allow(dead_code)]
pub fn legal_actions(h: &History, bet_sizes: (f64, f64, f64), max_wagers: u32) -> Vec<u8> {
    let (tokens, _bet_size, _street) =
        active_round_for(&h.board, &h.flop_a, &h.turn_a, &h.river_a, bet_sizes)
            .expect("legal_actions called on a history with no active round");
    legal_for_tokens(&tokens, max_wagers).expect("legal_actions called on a completed round")
}

/// Full `returns` port, including showdown -- calls into Stage 8R-2's
/// `cards::evaluate_best_hand` for the hand comparison. NOT part of the
/// exploitability walk itself; just the terminal-utility computation.
pub fn returns(
    hero_combo: Combo,
    villain_combo: Combo,
    board: &BoardBuf,
    flop_a: &TokenBuf,
    turn_a: &TokenBuf,
    river_a: &TokenBuf,
    preflop_contrib: (f64, f64),
    bet_sizes: (f64, f64, f64),
) -> [f64; 2] {
    let (contrib_flop, folder_flop) = simulate_round(flop_a, bet_sizes.0);
    if let Some(folder) = folder_flop {
        let total = [
            preflop_contrib.0 + contrib_flop.0,
            preflop_contrib.1 + contrib_flop.1,
        ];
        return payoffs_from_fold(total, folder);
    }

    let (contrib_turn, folder_turn) = simulate_round(turn_a, bet_sizes.1);
    if let Some(folder) = folder_turn {
        let total = [
            preflop_contrib.0 + contrib_flop.0 + contrib_turn.0,
            preflop_contrib.1 + contrib_flop.1 + contrib_turn.1,
        ];
        return payoffs_from_fold(total, folder);
    }

    let (contrib_river, folder_river) = simulate_round(river_a, bet_sizes.2);
    let total = [
        preflop_contrib.0 + contrib_flop.0 + contrib_turn.0 + contrib_river.0,
        preflop_contrib.1 + contrib_flop.1 + contrib_turn.1 + contrib_river.1,
    ];
    if let Some(folder) = folder_river {
        return payoffs_from_fold(total, folder);
    }

    let mut hero_cards: Vec<u8> = vec![hero_combo.0, hero_combo.1];
    hero_cards.extend_from_slice(board.as_slice());
    let mut villain_cards: Vec<u8> = vec![villain_combo.0, villain_combo.1];
    villain_cards.extend_from_slice(board.as_slice());
    let hero_rank = cards::evaluate_best_hand(&hero_cards);
    let villain_rank = cards::evaluate_best_hand(&villain_cards);
    let equity = if hero_rank > villain_rank {
        1.0
    } else if hero_rank < villain_rank {
        0.0
    } else {
        0.5
    };
    let pot = total[0] + total[1];
    [equity * pot - total[0], (1.0 - equity) * pot - total[1]]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legal_for_tokens_after_a_check_is_check_or_bet() {
        let tokens = TokenBuf::from_str("x");
        assert_eq!(legal_for_tokens(&tokens, 1).unwrap(), vec![b'x', b'b']);
    }

    #[test]
    fn legal_for_tokens_after_a_bet_at_the_wager_cap_is_fold_or_call_only() {
        let tokens = TokenBuf::from_str("b");
        assert_eq!(legal_for_tokens(&tokens, 1).unwrap(), vec![b'f', b'c']);
    }

    #[test]
    fn legal_for_tokens_after_a_bet_below_the_wager_cap_allows_a_raise() {
        let tokens = TokenBuf::from_str("b");
        assert_eq!(legal_for_tokens(&tokens, 2).unwrap(), vec![b'f', b'c', b'b']);
    }

    #[test]
    fn simulate_round_check_check_has_zero_contribution_and_no_folder() {
        let tokens = TokenBuf::from_str("xx");
        assert_eq!(simulate_round(&tokens, 2.5), ((0.0, 0.0), None));
    }

    #[test]
    fn simulate_round_bet_fold_credits_the_bettor_nothing_back() {
        // "bf": player 0 bets 2.5, player 1 folds.
        let tokens = TokenBuf::from_str("bf");
        assert_eq!(simulate_round(&tokens, 2.5), ((2.5, 0.0), Some(1)));
    }

    #[test]
    fn payoffs_from_fold_line_matches_hand_computation() {
        // preflop_contrib (2.5, 2.5), flop "bf": player0 bet 2.5, player1 folds.
        let board = BoardBuf::from_slice(&[0, 4, 8]);
        let flop_a = TokenBuf::from_str("bf");
        let turn_a = TokenBuf::EMPTY;
        let river_a = TokenBuf::EMPTY;
        let result = returns(
            (10, 20),
            (11, 21),
            &board,
            &flop_a,
            &turn_a,
            &river_a,
            (2.5, 2.5),
            (2.5, 5.0, 7.5),
        );
        // Player 1 folds: pot = 2.5+2.5(preflop) + 2.5+0(flop) = 7.5;
        // total = [5.0, 2.5]; winner=0 gets pot-total[0]=2.5, folder=1 loses -2.5.
        assert_eq!(result, [2.5, -2.5]);
    }

    #[test]
    fn information_set_key_uses_pipe_separators_and_two_digit_cards() {
        let combo = (10u8, 39u8);
        let board = BoardBuf::from_slice(&[0, 4, 8]);
        let flop_a = TokenBuf::from_str("xb");
        let turn_a = TokenBuf::EMPTY;
        let river_a = TokenBuf::EMPTY;
        let key = information_set_key(combo, &board, &flop_a, &turn_a, &river_a);
        assert_eq!(key, "1039000408|xb||");
    }
}
