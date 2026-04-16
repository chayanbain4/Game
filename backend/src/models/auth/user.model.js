const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    number: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
      required: true,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    wins: {
      type: Number,
      default: 0,
    },
    balance: {
      type: Number,
      default: 0,
    },
    welcomeBonusClaimed: {
      type: Boolean,
      default: false,
    },

    // ── Global games played (kept for backward compatibility) ──
    totalGamesPlayed: {
      type: Number,
      default: 0,
    },

    // ── Per-game played counters ───────────────────────────────
    // Each game tracks its OWN play count independently.
    // Early-boost (games 0–3 → 97% win) is applied PER GAME so that
    // playing Number Game 10 times does NOT consume the Andar Bahar
    // or Scratch boost — every game starts fresh for every user.
    numberGamesPlayed:     { type: Number, default: 0 },
    andarbaharGamesPlayed: { type: Number, default: 0 },
    scratchGamesPlayed:    { type: Number, default: 0 },
    lotteryGamesPlayed:    { type: Number, default: 0 },
    superlotoGamesPlayed:  { type: Number, default: 0 },
    ludoGamesPlayed:       { type: Number, default: 0 },
    rouletteGamesPlayed:   { type: Number, default: 0 },

    gamesSinceLastReward: {
      type: Number,
      default: 0,
    },

    // Daily reward streak
    dailyRewardStreak: {
      type: Number,
      default: 0,
    },
    lastDailyRewardDate: {
      type: String, // YYYY-MM-DD
      default: null,
    },
    freeSpins: {
      type: Number,
      default: 0,
    },
    lossStreak: {
      type: Number,
      default: 0,
    },

    // ── Andar Bahar outcome control ────────────────────────────
    abWinStreak:       { type: Number, default: 0 },
    abLossStreak:      { type: Number, default: 0 },
    abWinCap:          { type: Number, default: 0 },
    abLossCap:         { type: Number, default: 0 },
    abAttractionBurst: { type: Number, default: 0 },

    // ── Per-game loss streaks for 7-loss attraction burst ──────
    // Each game tracks its own consecutive loss count independently.
    // After 7 losses in a SPECIFIC game → sudden forced win in THAT game only.
    scratchLossStreak:    { type: Number, default: 0 },
    lotteryLossStreak:    { type: Number, default: 0 },
    superlotoLossStreak:  { type: Number, default: 0 },
    numberLossStreak:     { type: Number, default: 0 },
    andarbaharLossStreak: { type: Number, default: 0 },

    // ── Roulette outcome control ────────────────────────────────
    rouletteLossStreak:      { type: Number, default: 0 },
    rouletteAttractionBurst: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model("User", userSchema);