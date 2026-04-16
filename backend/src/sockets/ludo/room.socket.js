const Room = require("../../models/ludo/room.model");
const { createGame, getGame } = require("../../game/ludo/game.state");

// In-memory waiting room: roomCode → [userId, userId, ...]
const waitingPlayers = {};

const MIN_PLAYERS = 2;
const MAX_PLAYERS = 4;

module.exports = function (io, socket, userSockets) {

  socket.on("join_room", async ({ code, userId }) => {

    const playerId = socket.userId || userId;

    // 1. Join socket channel FIRST — unconditionally
    socket.join(code);
    console.log(`[room] ${playerId} joined room: ${code}`);

    // 2. Init waiting list for this room if needed
    if (!waitingPlayers[code]) {
      waitingPlayers[code] = [];
    }

    // 3. Add player only once
    if (!waitingPlayers[code].includes(playerId)) {
      waitingPlayers[code].push(playerId);
    }

    const playerCount = waitingPlayers[code].length;
    console.log(`[room] Room ${code} players (${playerCount}):`, waitingPlayers[code]);

    // 4. Check if a game already exists (reconnect case)
    try {
      const existingGame = await getGame(code);
      if (existingGame) {
        console.log(`[room] Game already running for ${code} — resending state`);
        io.to(socket.id).emit("game_started", existingGame);
        io.to(socket.id).emit("game_state", existingGame);
        delete waitingPlayers[code];
        return;
      }
    } catch (err) {
      console.error("[room] Redis check error:", err.message);
    }

    // 5. Tell everyone who is waiting
    io.to(code).emit("waiting_update", {
      roomCode: code,
      players: waitingPlayers[code],
      needed: MIN_PLAYERS,
    });

    // 6. Auto-start when MIN_PLAYERS joined
    if (playerCount >= MIN_PLAYERS) {
      console.log(`[room] ${playerCount} players ready — starting game in ${code}`);

      const players = [...waitingPlayers[code]];
      delete waitingPlayers[code];

      try {
        const game = await createGame(code, players);
        // Broadcast game_started to ALL sockets in this room
        io.to(code).emit("game_started", game);
        console.log(`[room] game_started emitted to room ${code}`, players);
      } catch (err) {
        console.error("[room] createGame failed:", err.message);
        io.to(code).emit("error", { message: "Failed to start game. Try again." });
      }
    }

  });

  // Host can force-start before MAX_PLAYERS (e.g. solo testing)
  socket.on("force_start", async ({ code }) => {
    const players = waitingPlayers[code];
    if (!players || players.length < 1) {
      socket.emit("error", { message: "No players in room" });
      return;
    }

    delete waitingPlayers[code];

    try {
      const game = await createGame(code, players);
      io.to(code).emit("game_started", game);
      console.log(`[room] Force-started game in ${code}`);
    } catch (err) {
      console.error("[room] force_start error:", err.message);
    }
  });

  socket.on("disconnect", () => {
    const userId = socket.userId;
    if (!userId) return;

    for (const code of Object.keys(waitingPlayers)) {
      waitingPlayers[code] = waitingPlayers[code].filter(id => id !== userId);
      if (waitingPlayers[code].length === 0) {
        delete waitingPlayers[code];
      } else {
        io.to(code).emit("waiting_update", {
          roomCode: code,
          players: waitingPlayers[code],
          needed: MIN_PLAYERS,
        });
      }
    }
  });

};