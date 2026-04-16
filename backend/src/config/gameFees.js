// Per-game entry fee configuration (in ₹)
const FEES = {
  LUDO:       10,
  NUMBER:      3,
  SCRATCH:     5,
  LOTTERY:     2,
  SUPERLOTO:   2,
  ANDARBAHAR:  4,
  ROULETTE:   10,  // ← minimum chip / bet amount
};

const WIN_REWARDS = {
  LUDO:       20,
  NUMBER:      6,
  SCRATCH:    10,
  ANDARBAHAR:  8,

  LOTTERY: {
    TIER_2:   6,
    TIER_1:  12,
  },

  SUPERLOTO: {
    TIER_3:   24,
    TIER_2:   24,
    TIER_1:   24,
    TIER_0:   24,
  },

  // ── Roulette casino-style multipliers ────────────────────────
  //   Payout = betAmount × multiplier
  //   e.g. bet ₹10 on red  → win ₹20 (2x)
  //        bet ₹10 on dozen → win ₹50 (5x)
  //        bet ₹10 on "7"  → win ₹190 (19x)
  ROULETTE: {
    COLOR:  2,   // red / black / green   → 2x
    PARITY: 2,   // odd / even            → 2x
    HALF:   2,   // low (1-18) / high (19-36) → 2x
    DOZEN:  2,   // 1st / 2nd / 3rd dozen → 2x
    COLUMN: 2,   // col1 / col2 / col3    → 2x
    NUMBER: 2,   // single number 0–36    → 2x
  },
};

module.exports = { ...FEES, WIN_REWARDS };