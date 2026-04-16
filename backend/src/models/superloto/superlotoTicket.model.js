const mongoose = require("mongoose");

const superlotoTicketSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
  },
  username: {
    type: String,
    default: "Anonymous",
  },
  drawNumber: {
    type: Number,
    required: true,
  },
  numbers: {
    type: [Number],
    required: true,
  },
  isQuickPick: {
    type: Boolean,
    default: false,
  },
  // ── Multiplier: 1 | 2 | 5 | 10 ─────────────────────────────
  // MUST be in the schema or Mongoose strips it before saving.
  // executeDraw() reads this field to scale the prize correctly.
  multiplier: {
    type: Number,
    enum: [1, 2, 5, 10],
    default: 1,
  },
  matchedNumbers: {
    type: [Number],
    default: [],
  },
  matchCount: {
    type: Number,
    default: 0,
  },
  result: {
    type: String,
    enum: ["PENDING", "WIN", "LOSE"],
    default: "PENDING",
  },
  tier: {
    type: String,
    default: null,
  },
  tierLabel: {
    type: String,
    default: null,
  },
  winAmount: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("SuperLotoTicket", superlotoTicketSchema);