const mongoose = require("mongoose");

const scratchResultSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
  },
  username: {
    type: String,
    default: "Anonymous",
  },
  cells: {
    type: [String],
    required: true,
  },
  result: {
    type: String,
    enum: ["WIN", "LOSE"],
    required: true,
  },
  symbol: {
    type: String,
    default: null,
  },
  matchCount: {
    type: Number,
    default: 0,
  },
  multiplier: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("ScratchResult", scratchResultSchema);
