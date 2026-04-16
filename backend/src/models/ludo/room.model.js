const mongoose = require("mongoose");

const playerSchema = new mongoose.Schema(
 {
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  seatIndex: Number
 },
 { _id: false }
);

const roomSchema = new mongoose.Schema(
 {
  code: { type: String, unique: true },
  hostUserId: mongoose.Schema.Types.ObjectId,
  status: {
   type: String,
   enum: ["WAITING", "PLAYING", "FINISHED"],
   default: "WAITING"
  },
  players: [playerSchema],
  maxPlayers: { type: Number, default: 4 }
 },
 { timestamps: true }
);

module.exports = mongoose.model("Room", roomSchema);