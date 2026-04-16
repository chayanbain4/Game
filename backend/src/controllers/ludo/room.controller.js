const { createRoom, getRoom } = require("../../services/ludo/room.service");

async function createRoomController(req, res) {
 const room = await createRoom(req.user.userId);
 res.json(room);
}

async function getRoomController(req, res) {
 const room = await getRoom(req.params.code);

 if (!room) return res.status(404).json({ message: "Room not found" });

 res.json(room);
}

module.exports = { createRoomController, getRoomController };