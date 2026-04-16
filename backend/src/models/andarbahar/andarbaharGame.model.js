const mongoose = require("mongoose");

const cardSchema = new mongoose.Schema({
  value: { type: String, required: true },
  suit:  { type: String, required: true },
}, { _id: false });

const andarBaharGameSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true,
  },
  username: {
    type: String,
    default: "Anonymous",
  },
  playerChoice: {
    type: String,
    enum: ["ANDAR", "BAHAR"],
    required: true,
  },
  jokerCard: {
    type: cardSchema,
    required: true,
  },
  andarCards: {
    type: [cardSchema],
    default: [],
  },
  baharCards: {
    type: [cardSchema],
    default: [],
  },
  matchingCard: {
    type: cardSchema,
    default: null,
  },
  winningSide: {
    type: String,
    enum: ["ANDAR", "BAHAR"],
    required: true,
  },
  result: {
    type: String,
    enum: ["WIN", "LOSE"],
    required: true,
  },
  totalDealt: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("AndarBaharGame", andarBaharGameSchema);
