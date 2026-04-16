const mongoose = require("mongoose");

const jackpotSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
    },
    displayAmount: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      default: "Play now and win big!",
    },
    icon: {
      type: String,
      default: "trophy",
    },
    targetAmount: {
      type: Number,
      default: 0,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    sortOrder: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Jackpot", jackpotSchema);
