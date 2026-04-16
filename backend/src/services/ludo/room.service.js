const Room = require("../../models/ludo/room.model");
const generateCode = require("../../utils/ludo/generateCode");

async function createRoom(userId) {
 const code = generateCode();

 const room = await Room.create({
  code,
  hostUserId: userId,
  players: [{ userId, seatIndex: 0 }]
 });

 return room;
}

async function getRoom(code) {
 return Room.findOne({ code });
}

module.exports = { createRoom, getRoom };