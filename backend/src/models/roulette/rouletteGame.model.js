const mongoose = require("mongoose");

const betSchema = new mongoose.Schema({
  betType:   { type: String, required: true },   // color | parity | half | dozen | column | number
  betValue:  { type: mongoose.Schema.Types.Mixed, required: true },
  amount:    { type: Number, required: true },
  won:       { type: Boolean, default: false },
  winAmount: { type: Number, default: 0 },
  payout:    { type: Number, default: 0 },       // e.g. 2, 5, 19
}, { _id: false });

const rouletteGameSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true,
  },
  username: {
    type: String,
    default: "Anonymous",
  },

  // ── Bets placed by player ─────────────────────────────────
  bets:     { type: [betSchema], required: true },
  totalBet: { type: Number, required: true },

  // ── Spin result ───────────────────────────────────────────
  spinResult: { type: Number, required: true },   // 0–36
  resultColor:  { type: String },                  // red | black | green
  resultParity: { type: String },                  // odd | even | zero
  resultHalf:   { type: String },                  // low | high | zero
  resultDozen:  { type: String },                  // 1st | 2nd | 3rd | zero
  resultColumn: { type: String },                  // col1 | col2 | col3 | zero

  // ── Outcome ───────────────────────────────────────────────
  totalWin:  { type: Number, default: 0 },
  result:    { type: String, enum: ["WIN", "LOSE"], required: true },
  winType:   { type: String, default: "normal" },   // normal | rare | popular | jackpot

  // ── Engagement ───────────────────────────────────────────
  freeSpinUsed: { type: Boolean, default: false },

  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("RouletteGame", rouletteGameSchema);