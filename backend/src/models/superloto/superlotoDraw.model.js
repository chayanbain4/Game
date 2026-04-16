const mongoose = require("mongoose");

const superlotoDrawSchema = new mongoose.Schema({
  drawNumber: {
    type: Number,
    required: true,
    unique: true,
  },
  winningNumbers: {
    type: [Number],
    required: true,
  },
  totalTickets: {
    type: Number,
    default: 0,
  },
  totalWinners: {
    type: Number,
    default: 0,
  },
  status: {
    type: String,
    enum: ["UPCOMING", "OPEN", "DRAWN"],
    default: "OPEN",
  },
  drawnAt: {
    type: Date,
    default: null,
  },
  winType: {
    type: String,
    enum: ["normal", "rare", "popular"],
    default: "normal",
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("SuperLotoDraw", superlotoDrawSchema);
