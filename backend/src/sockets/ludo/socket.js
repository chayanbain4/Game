// sockets/ludo/socket.js
//
// Main Ludo socket initialiser.
// Called from server.js as:  initLudoSocket(io)
//
// Registers per-connection handlers for:
//   - room.socket.js      (join_room, force_start)
//   - game.socket.js      (roll_dice, move_token, start_game)
//   - matchmaking.socket.js  (find_match, cancel_match)  ← NEW

const roomSocket        = require("./room.socket");
const gameSocket        = require("./game.socket");
const matchmakingSocket = require("./Matchmaking.socket.js");

// userId → socketId   (used for targeted direct messages if needed)
const userSockets = {};

function initLudoSocket(io) {

  io.on("connection", (socket) => {

    // ── Identify the user ──────────────────────────────────────
    // userId comes from the socket handshake query:
    //   SocketService().connect(userId)  passes  ?userId=xxx
    // TODO: replace with JWT verification once auth is hardened
    const { userId } = socket.handshake.query;

    if (userId) {
      userSockets[userId] = socket.id;
      socket.userId       = userId;
    }

    console.log(`[socket] connected  id=${socket.id}  userId=${userId ?? "anon"}`);

    // ── Register all handler modules ───────────────────────────
    roomSocket(io, socket, userSockets);
    gameSocket(io, socket, userSockets);
    matchmakingSocket(io, socket);

    // ── Clean up on disconnect ─────────────────────────────────
    socket.on("disconnect", () => {
      console.log(`[socket] disconnected  id=${socket.id}  userId=${socket.userId ?? "anon"}`);
      if (socket.userId) {
        delete userSockets[socket.userId];
      }
    });
  });
}

module.exports = initLudoSocket;