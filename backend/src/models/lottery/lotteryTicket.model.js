const mongoose = require("mongoose");

const lotteryTicketSchema = new mongoose.Schema({
  userId:         { type: String, required: true },
  username:       { type: String, default: "Anonymous" },
  drawNumber:     { type: Number, required: true },
  numbers:        { type: [Number], required: true },
  isQuickPick:    { type: Boolean, default: false },

  // ── CRITICAL: must be in schema or Mongoose silently strips it ──
  // executeDraw reads this to scale prize: basePrize × multiplier
  // Missing field = always reads as undefined → defaults to 1 → wrong prize
  multiplier:     { type: Number, enum: [1, 2, 5, 10], default: 1 },

  matchedNumbers: { type: [Number], default: [] },
  matchCount:     { type: Number, default: 0 },
  result:         { type: String, enum: ["PENDING", "WIN", "LOSE"], default: "PENDING" },
  tier:           { type: String, default: null },
  tierLabel:      { type: String, default: null },
  winAmount:      { type: Number, default: 0 },
  createdAt:      { type: Date, default: Date.now },
});

module.exports = mongoose.models.LotteryTicket
  || mongoose.model("LotteryTicket", lotteryTicketSchema);