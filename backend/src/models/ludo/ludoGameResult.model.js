const mongoose = require("mongoose");

const ludoGameResultSchema = new mongoose.Schema({
  players: [{
    userId: { type: String, required: true },
    username: { type: String, default: "Anonymous" },
    result: { type: String, enum: ["WIN", "LOSE"], required: true },
  }],
  winnerId: { type: String, required: true },
  winnerName: { type: String, default: "Anonymous" },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("LudoGameResult", ludoGameResultSchema);
