//! Fixed-size, `Copy`, zero-heap-allocation representations of
//! `PostflopSubgame`'s history pieces (Stage 8R-3). Python's history is a
//! 6-tuple `(hero_combo, villain_combo, board, flop_a, turn_a, river_a)`
//! where the three action-strings are plain `str`s built one character at a
//! time from `{"x","b","c","f"}` and `board` grows from 3 to 5 cards. Since
//! `max_wagers_per_round` genuinely bounds every reachable token string's
//! length (see `rules.rs`'s module docs for the bound), and the board never
//! exceeds 5 cards, both fit comfortably in fixed-size stack buffers -- a
//! legitimate place to avoid heap allocation given `exploitability`'s walk
//! (a later stage) calls into this tens of millions of times.

/// A two-card combo, card ids 0..51, normalized so `.0 <= .1` (mirrors
/// Python's `Combo = tuple[int, int]` from `cfr_solver.poker.combos`, which
/// is likewise always stored with the smaller id first).
pub type Combo = (u8, u8);

/// One street's action token string (`"x"`/`"b"`/`"c"`/`"f"` characters),
/// stored inline instead of heap-allocated. 8 bytes is comfortably larger
/// than any reachable token string (see `rules.rs`'s bound discussion).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct TokenBuf {
    pub len: u8,
    pub bytes: [u8; 8],
}

impl TokenBuf {
    // Used by `rules.rs`'s unit tests and by `next_history` (itself not yet
    // wired to any debug binding -- see `rules.rs`'s `#[allow(dead_code)]`
    // note on that function).
    #[allow(dead_code)]
    pub const EMPTY: TokenBuf = TokenBuf { len: 0, bytes: [0u8; 8] };

    pub fn from_str(s: &str) -> Self {
        assert!(
            s.len() <= 8,
            "token string {s:?} exceeds the 8-byte TokenBuf capacity"
        );
        assert!(s.is_ascii(), "token string {s:?} must be ASCII");
        let mut bytes = [0u8; 8];
        bytes[..s.len()].copy_from_slice(s.as_bytes());
        TokenBuf { len: s.len() as u8, bytes }
    }

    pub fn as_str(&self) -> &str {
        std::str::from_utf8(&self.bytes[..self.len as usize])
            .expect("TokenBuf must always hold valid ASCII")
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    pub fn last(&self) -> Option<u8> {
        if self.len == 0 {
            None
        } else {
            Some(self.bytes[self.len as usize - 1])
        }
    }

    pub fn count(&self, ch: u8) -> usize {
        self.bytes[..self.len as usize].iter().filter(|&&b| b == ch).count()
    }

    /// Returns a new `TokenBuf` with `ch` appended (used by `next_history`).
    #[allow(dead_code)]
    pub fn pushed(&self, ch: u8) -> Self {
        let mut bytes = self.bytes;
        assert!(
            (self.len as usize) < bytes.len(),
            "token string overflowed the 8-byte TokenBuf capacity"
        );
        bytes[self.len as usize] = ch;
        TokenBuf { len: self.len + 1, bytes }
    }
}

/// The community board, 3 (flop) to 5 (river) cards, card ids 0..51.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct BoardBuf {
    pub len: u8,
    pub cards: [u8; 5],
}

impl BoardBuf {
    pub fn from_slice(cards: &[u8]) -> Self {
        assert!(cards.len() <= 5, "board has more than 5 cards: {cards:?}");
        let mut c = [0u8; 5];
        c[..cards.len()].copy_from_slice(cards);
        BoardBuf { len: cards.len() as u8, cards: c }
    }

    pub fn as_slice(&self) -> &[u8] {
        &self.cards[..self.len as usize]
    }

    #[allow(dead_code)]
    pub fn pushed(&self, card: u8) -> Self {
        let mut cards = self.cards;
        assert!((self.len as usize) < cards.len(), "board already has 5 cards");
        cards[self.len as usize] = card;
        BoardBuf { len: self.len + 1, cards }
    }
}

/// Rust twin of Python's `History` 6-tuple for `PostflopSubgame`. `Copy` so
/// it can be passed around and mutated-by-copy (`next_history`) with zero
/// heap allocation, matching how cheaply Python's immutable tuple is
/// conceptually threaded through the game tree.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct History {
    pub hero_combo: Option<Combo>,
    pub villain_combo: Option<Combo>,
    pub board: BoardBuf,
    pub flop_a: TokenBuf,
    pub turn_a: TokenBuf,
    pub river_a: TokenBuf,
}
