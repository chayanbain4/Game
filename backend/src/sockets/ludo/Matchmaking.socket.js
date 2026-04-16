// src/sockets/ludo/Matchmaking.socket.js
//
// Flow:
//   Player emits find_match
//   → If another player already waiting → pair immediately as REAL match
//   → If no one waiting → enter queue, wait 15s for real player
//       → Real player joins within 15s → pair as REAL match (cancel bot timer)
//       → No one joins in 15s        → start game with BOT (client never knows)

const { createGame, getGame }  = require("../../game/ludo/game.state");
const { customAlphabet }        = require("nanoid");
const User                      = require("../../models/auth/user.model");
const FEES                      = require("../../config/gameFees");
const { getFakeBotProfile }     = require("../../config/botProfiles");
const { redis }                 = require("../../config/redis");

const alphabet     = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const nanoid       = customAlphabet(alphabet, 6);
const BOT_WAIT_MS  = 15000;   // 15 seconds wait for real player

// ── Module-level state ────────────────────────────────────────
let waitingSlot = null;        // { socketId, userId, roomCode }
const botTimers = {};          // socketId → setTimeout handle

// ─────────────────────────────────────────────────────────────

module.exports = function (io, socket) {

  // ── FIND MATCH ─────────────────────────────────────────────
  socket.on("find_match", async (payload = {}) => {
    const userId = payload.userId || socket.userId;

    if (!userId) {
      return socket.emit("match_error", { message: "User ID is required." });
    }
    socket.userId = userId;

    // ── Deduct entry fee (or use free spin) ─────────────────
    try {
      const email   = String(userId).trim().toLowerCase();
      const userDoc = await User.findOne({ email });

      if (!userDoc) {
        return socket.emit("match_error", { message: "User not found." });
      }

      if ((userDoc.freeSpins || 0) > 0) {
        userDoc.freeSpins -= 1;
      } else {
        if (userDoc.balance < FEES.LUDO) {
          return socket.emit("match_error", {
            message: `Insufficient balance. Need ₹${FEES.LUDO}, have ₹${userDoc.balance}`,
          });
        }
        userDoc.balance -= FEES.LUDO;
      }

      await userDoc.save();
      socket.emit("balance_update", {
        newBalance: userDoc.balance,
        freeSpins:  userDoc.freeSpins || 0,
      });
    } catch (err) {
      console.error("[matchmaking] fee error:", err.message);
      return socket.emit("match_error", { message: "Failed to deduct entry fee." });
    }

    // Guard: already in waiting slot
    if (waitingSlot && waitingSlot.socketId === socket.id) {
      console.log(`[matchmaking] ${userId} already waiting — ignoring duplicate`);
      return;
    }

    // ── CASE 1: Real player already waiting → pair them ──────
    if (waitingSlot) {
      const { roomCode, userId: firstUserId, socketId: firstSocketId } = waitingSlot;
      waitingSlot = null;

      // Cancel first player's bot timer — real match found in time!
      if (botTimers[firstSocketId]) {
        clearTimeout(botTimers[firstSocketId]);
        delete botTimers[firstSocketId];
        console.log(`[matchmaking] bot timer cancelled — real player found for ${firstUserId}`);
      }

      socket.join(roomCode);

      try {
        const existing = await getGame(roomCode);
        if (existing) {
          io.to(roomCode).emit("game_started", { ...existing });
          return;
        }

        const [u1, u2] = await Promise.all([
          User.findOne({ email: firstUserId }),
          User.findOne({ email: userId }),
        ]);

        const game = await createGame(roomCode, [firstUserId, userId]);

        io.to(roomCode).emit("game_started", {
          ...game,
          playerProfiles: {
            [firstUserId]: {
              name:  u1?.name ?? firstUserId,
              wins:  u1?.wins ?? 0,
            },
            [userId]: {
              name:  u2?.name ?? userId,
              wins:  u2?.wins ?? 0,
            },
          },
        });

        console.log(`[matchmaking] REAL match: ${firstUserId} vs ${userId} in ${roomCode}`);
      } catch (err) {
        console.error("[matchmaking] createGame error:", err.message);
        io.to(roomCode).emit("match_error", { message: "Failed to start game." });
      }
      return;
    }

    // ── CASE 2: No one waiting → queue + start 15s bot timer ─
    const roomCode = nanoid();
    socket.join(roomCode);
    waitingSlot = { socketId: socket.id, userId, roomCode };
    socket.emit("match_waiting", { roomCode });

    console.log(`[matchmaking] ${userId} waiting in ${roomCode} — 15s bot timer started`);

    // Fetch profile now so it's ready when bot timer fires
    const userDocForBot = await User
      .findOne({ email: String(userId).trim().toLowerCase() })
      .catch(() => null);

    botTimers[socket.id] = setTimeout(async () => {
      // Clear slot if still there (wasn't matched with real player)
      if (waitingSlot?.socketId === socket.id) waitingSlot = null;
      delete botTimers[socket.id];

      try {
        const bot  = getFakeBotProfile();
        const game = await createGame(roomCode, [userId, bot.id]);

        // Store bot info in Redis so game.socket.js detects bot turns
        await redis.set(
          `bot:${roomCode}`,
          JSON.stringify({ botId: bot.id, botColor: "blue" })
        );

        // Send to client — looks IDENTICAL to a real match
        // isBot / vsBot are NEVER included in the payload
        socket.emit("game_started", {
          ...game,
          playerProfiles: {
            [userId]: {
              name:  userDocForBot?.name ?? userId,
              wins:  userDocForBot?.wins ?? 0,
            },
            [bot.id]: {
              name:  bot.name,   // fake name — client sees as real
              wins:  bot.wins,   // fake wins — client sees as real
            },
          },
        });

        console.log(`[matchmaking] BOT match: ${userId} vs fake "${bot.name}" in ${roomCode}`);

      } catch (err) {
        console.error("[matchmaking] bot start error:", err.message);
        socket.emit("match_error", { message: "Failed to start game. Please try again." });
      }
    }, BOT_WAIT_MS);
  });

  // ── CANCEL MATCH ───────────────────────────────────────────
  socket.on("cancel_match", () => {
    const removed = _removeFromQueue(socket);
    if (removed) console.log(`[matchmaking] ${socket.userId} cancelled search`);
    socket.emit("match_cancelled", { reason: "Search cancelled." });
  });

  // ── DISCONNECT ─────────────────────────────────────────────
  socket.on("disconnect", () => {
    _removeFromQueue(socket);
  });
};

// ── Helper: remove from queue + cancel bot timer ─────────────
function _removeFromQueue(socket) {
  if (botTimers[socket.id]) {
    clearTimeout(botTimers[socket.id]);
    delete botTimers[socket.id];
  }
  if (waitingSlot && waitingSlot.socketId === socket.id) {
    waitingSlot = null;
    console.log(`[matchmaking] removed ${socket.userId ?? socket.id} from queue`);
    return true;
  }
  return false;
}