// src/sockets/ludo/game.socket.js

const crypto = require("crypto");
const { createGame, getGame, saveGame, removeGame } = require("../../game/ludo/game.state");
const { BOARD_SIZE, SAFE_CELLS }                    = require("../../game/ludo/constants");
const { redis }                                      = require("../../config/redis");
const User                                           = require("../../models/auth/user.model");
const LudoGameResult                                 = require("../../models/ludo/ludoGameResult.model");
const FEES                                           = require("../../config/gameFees");

const COLOR_START = {
  red:    1,
  blue:   14,
  green:  27,
  yellow: 40,
};

const TURN_TIME = 15000;
const timerMap  = {};

// ─────────────────────────────────────────────────────────────

module.exports = function (io, socket) {

  // ── ROLL DICE ───────────────────────────────────────────────
  socket.on("roll_dice", async ({ roomCode }) => {
    const game = await getGame(roomCode);
    if (!game) return _log("game not found", roomCode);

    const player = game.players[game.currentTurn];
    if (socket.userId !== player.id) return _log("not your turn", socket.userId);
    if (game.dice !== null) return _log("already rolled", roomCode);

    const dice     = crypto.randomInt(1, 7);
    const color    = player.color;
    const tokens   = game.tokens[color];
    const startPos = COLOR_START[color];

    console.log(`[roll_dice] ${color} rolled ${dice} in room ${roomCode}`);

    const hasValidMove = tokens.some((tPos) => {
      if (tPos === BOARD_SIZE) return false;
      if (tPos === 0)          return dice === 6;
      if (tPos > 52)           return (tPos + dice) <= BOARD_SIZE;
      const stepsTaken  = (tPos - startPos + 52) % 52;
      const stepsToHome = 51 - stepsTaken;
      if (dice <= stepsToHome) return true;
      return (52 + (dice - stepsToHome)) <= BOARD_SIZE;
    });

    if (!hasValidMove) {
      const skippedTurn  = game.currentTurn;
      game.dice          = null;
      game.currentTurn   = (game.currentTurn + 1) % game.players.length;
      await saveGame(roomCode, game);

      let reason;
      if (tokens.every(t => t === 0)) {
        reason = "Need a 6 to enter the board";
      } else if (dice === 6) {
        reason = "No token can move with a 6";
      } else {
        reason = "No valid move — need exact number to reach home";
      }

      console.log(`[roll_dice] auto-skip ${color} (dice=${dice}) → turn ${game.currentTurn}`);

      io.to(roomCode).emit("turn_skipped", {
        dice,
        reason,
        skippedTurn,
        nextTurn: game.currentTurn,
      });

      _startTurnTimer(io, roomCode);
      _scheduleBotTurn(io, roomCode);   // ← bot check after skip
      return;
    }

    game.dice = dice;
    await saveGame(roomCode, game);

    io.to(roomCode).emit("dice_result", { dice, turn: game.currentTurn });
  });


  // ── MOVE TOKEN ──────────────────────────────────────────────
  socket.on("move_token", async ({ roomCode, tokenIndex }) => {
    const game = await getGame(roomCode);
    if (!game) return _log("game not found", roomCode);

    if (game.dice === null) {
      return socket.emit("invalid_move", { message: "Roll dice first" });
    }

    const player = game.players[game.currentTurn];
    if (socket.userId !== player.id) return _log("not your turn", socket.userId);
    if (tokenIndex < 0 || tokenIndex > 3) {
      return socket.emit("invalid_move", { message: "Invalid token index" });
    }

    const color = player.color;
    const dice  = game.dice;
    let   pos   = game.tokens[color][tokenIndex];

    console.log(`[move_token] ${color} token[${tokenIndex}] pos=${pos} dice=${dice}`);

    if (pos === BOARD_SIZE) {
      return socket.emit("invalid_move", { message: "Token is already home" });
    }

    if (pos === 0) {
      if (dice !== 6) return socket.emit("invalid_move", { message: "Need a 6 to leave base" });
      pos = COLOR_START[color];
    } else {
      const outerTrack  = 52;
      const startPos    = COLOR_START[color];
      const stepsTaken  = (pos - startPos + outerTrack) % outerTrack;
      const stepsToHome = (outerTrack - 1) - stepsTaken;

      if (pos > outerTrack) {
        const newPos = pos + dice;
        if (newPos > BOARD_SIZE) return socket.emit("invalid_move", { message: "Need exact number to reach home" });
        pos = newPos;
      } else if (dice <= stepsToHome) {
        pos = ((pos - 1 + dice) % outerTrack) + 1;
      } else {
        const homeStep = dice - stepsToHome;
        const newPos   = outerTrack + homeStep;
        if (newPos > BOARD_SIZE) return socket.emit("invalid_move", { message: "Need exact number to reach home" });
        pos = newPos;
      }
    }

    if (_isBlocked(game, pos, color)) {
      return socket.emit("invalid_move", { message: "Cell is blocked by your own tokens" });
    }

    game.tokens[color][tokenIndex] = pos;

    let captured = false;
    if (pos <= 52 && !SAFE_CELLS.includes(pos)) {
      for (const otherColor of Object.keys(game.tokens)) {
        if (otherColor === color) continue;
        game.tokens[otherColor].forEach((t, i) => {
          if (t === pos) {
            game.tokens[otherColor][i] = 0;
            captured = true;
          }
        });
      }
    }

    // ── WIN CHECK ────────────────────────────────────────────
    if (game.tokens[color].every(t => t === BOARD_SIZE)) {
      console.log(`[move_token] WINNER: ${player.id} (${color})`);
      game.dice = null;
      await saveGame(roomCode, game);
      io.to(roomCode).emit("game_state", game);

      try {
        const winnerEmail = String(player.id || "").trim().toLowerCase();
        if (!winnerEmail) throw new Error("Winner email missing");

        const winAmount = FEES.WIN_REWARDS.LUDO;
        const updated   = await User.findOneAndUpdate(
          { email: winnerEmail },
          { $inc: { wins: 1, balance: winAmount } },
          { new: true }
        );

        if (!updated) console.log(`[win] user not found: ${winnerEmail}`);

        io.to(roomCode).emit("player_won", {
          player:      player.id,
          color,
          newWinCount: updated?.wins    ?? null,
          winAmount,
          newBalance:  updated?.balance ?? null,
        });

        await LudoGameResult.create({
          players: game.players.map(p => ({
            userId:   p.id,
            username: p.id,
            result:   p.id === player.id ? "WIN" : "LOSE",
          })),
          winnerId:   winnerEmail,
          winnerName: player.id,
        }).catch(e => console.error("[win] history save failed:", e.message));

      } catch (err) {
        console.error("[win] error:", err.message);
        io.to(roomCode).emit("player_won", {
          player: player.id, color,
          newWinCount: null, winAmount: 0, newBalance: null,
        });
      }

      _clearTimer(roomCode);
      setTimeout(() => removeGame(roomCode), 30000);
      redis.del(`bot:${roomCode}`).catch(() => {});
      return;
    }

    const bonusTurn = (dice === 6) || captured;
    if (!bonusTurn) {
      game.currentTurn = (game.currentTurn + 1) % game.players.length;
    }
    game.dice = null;
    await saveGame(roomCode, game);

    io.to(roomCode).emit("game_state", game);
    _startTurnTimer(io, roomCode);
    _scheduleBotTurn(io, roomCode);   // ← bot check after every move
  });


  // ── LEAVE GAME ──────────────────────────────────────────────
  socket.on("leave_game", async ({ roomCode }) => {
    if (!socket.userId) return;

    const game = await getGame(roomCode);
    if (!game) return;

    const isPlayer = game.players.some(p => p.id === socket.userId);
    if (!isPlayer) return;

    console.log(`[leave_game] ${socket.userId} left room ${roomCode}`);
    _clearTimer(roomCode);

    const remaining    = game.players.find(p => p.id !== socket.userId);
    const remainingBot = remaining?.id?.startsWith("BOT_");

    if (remaining && !remainingBot) {
      // Real opponent — award them the win
      try {
        const remainingEmail = String(remaining.id || "").trim().toLowerCase();
        if (!remainingEmail) throw new Error("Remaining email missing");

        const winAmount = FEES.WIN_REWARDS.LUDO;
        const updated   = await User.findOneAndUpdate(
          { email: remainingEmail },
          { $inc: { wins: 1, balance: winAmount } },
          { new: true }
        );

        if (!updated) console.log(`[leave_game] user not found: ${remainingEmail}`);

        await LudoGameResult.create({
          players: game.players.map(p => ({
            userId:   p.id,
            username: p.id,
            result:   p.id === remaining.id ? "WIN" : "LOSE",
          })),
          winnerId:   remainingEmail,
          winnerName: remaining.id,
        }).catch(e => console.error("[leave_game] history failed:", e.message));

        const remainingSocket = [...io.sockets.sockets.values()]
          .find(s => s.userId === remaining.id);

        if (remainingSocket) {
          remainingSocket.emit("opponent_left", {
            message:    "Your opponent left the game. You win! 🏆",
            wins:       updated?.wins    ?? null,
            winAmount,
            newBalance: updated?.balance ?? null,
          });
        }
      } catch (err) {
        console.error("[leave_game] DB error:", err.message);
        io.to(roomCode).emit("opponent_left", {
          message: "Your opponent left. You win!",
          wins: null, winAmount: FEES.WIN_REWARDS.LUDO, newBalance: null,
        });
      }
    }
    // If remaining is a bot — no DB update, no notification needed

    await removeGame(roomCode);
    redis.del(`bot:${roomCode}`).catch(() => {});
    socket.leave(roomCode);
  });


  // ── DISCONNECT ──────────────────────────────────────────────
  socket.on("disconnect", async () => {
    if (!socket.userId) return;

    const rooms = [...socket.rooms].filter(r => r !== socket.id);

    for (const roomCode of rooms) {
      const game = await getGame(roomCode);
      if (!game) continue;

      const isPlayer = game.players.some(p => p.id === socket.userId);
      if (!isPlayer) continue;

      console.log(`[disconnect] ${socket.userId} left room ${roomCode} mid-game`);
      _clearTimer(roomCode);

      const remaining    = game.players.find(p => p.id !== socket.userId);
      const remainingBot = remaining?.id?.startsWith("BOT_");

      if (remaining && !remainingBot) {
        // Real opponent — award win
        try {
          const remainingEmail = String(remaining.id || "").trim().toLowerCase();
          if (!remainingEmail) throw new Error("Remaining email missing");

          const updated = await User.findOneAndUpdate(
            { email: remainingEmail },
            { $inc: { wins: 1 } },
            { new: true }
          );

          io.to(roomCode).emit("opponent_left", {
            message:    "Your opponent disconnected. You win!",
            wins:       updated?.wins ?? null,
            winAmount:  FEES.WIN_REWARDS.LUDO,
            newBalance: null,
          });
        } catch (err) {
          console.error("[disconnect] DB error:", err.message);
          io.to(roomCode).emit("opponent_left", {
            message: "Your opponent disconnected. You win!",
            wins: null,
          });
        }
      }
      // If remaining is bot — no action needed

      await removeGame(roomCode);
      redis.del(`bot:${roomCode}`).catch(() => {});
    }
  });
};


// ═══════════════════════════════════════════════════════════════
// BOT AUTO-PLAY ENGINE
// ═══════════════════════════════════════════════════════════════

// Schedule a bot turn check with short delay
function _scheduleBotTurn(io, roomCode) {
  setTimeout(() => _handleBotTurn(io, roomCode), 600);
}

// Check if it's the bot's turn — if so, auto-roll and auto-move
async function _handleBotTurn(io, roomCode) {
  try {
    const botRaw = await redis.get(`bot:${roomCode}`);
    if (!botRaw) return; // not a bot game

    const { botId } = JSON.parse(botRaw);
    const game      = await getGame(roomCode);
    if (!game)               return; // game ended
    if (game.dice !== null)  return; // dice already rolled (shouldn't happen but guard)

    const currentPlayer = game.players[game.currentTurn];
    if (currentPlayer.id !== botId) return; // not bot's turn

    console.log(`[bot] turn in room ${roomCode} — bot is ${currentPlayer.color}`);

    // Clear existing turn timer (bot handles its own timing)
    _clearTimer(roomCode);

    // Think delay: 1.5s–3s (feels like a human thinking)
    const thinkDelay = 1500 + Math.random() * 1500;

    setTimeout(async () => {
      const freshGame = await getGame(roomCode);
      if (!freshGame) return;

      const cp = freshGame.players[freshGame.currentTurn];
      if (!cp || cp.id !== botId) return; // turn changed

      // ── Bot rolls dice ──────────────────────────────────────
      const dice      = crypto.randomInt(1, 7);
      const color     = cp.color;
      const tokens    = freshGame.tokens[color];
      const startPos  = COLOR_START[color];

      console.log(`[bot] rolled ${dice} (${color}) in ${roomCode}`);

      // Check if bot has any valid move
      const hasValidMove = tokens.some((tPos) => {
        if (tPos === BOARD_SIZE) return false;
        if (tPos === 0)          return dice === 6;
        if (tPos > 52)           return (tPos + dice) <= BOARD_SIZE;
        const stepsTaken  = (tPos - startPos + 52) % 52;
        const stepsToHome = 51 - stepsTaken;
        if (dice <= stepsToHome) return true;
        return (52 + (dice - stepsToHome)) <= BOARD_SIZE;
      });

      if (!hasValidMove) {
        // No valid move — skip turn
        const skippedTurn    = freshGame.currentTurn;
        freshGame.dice        = null;
        freshGame.currentTurn = (freshGame.currentTurn + 1) % freshGame.players.length;
        await saveGame(roomCode, freshGame);

        let reason;
        if (tokens.every(t => t === 0)) {
          reason = "Need a 6 to enter the board";
        } else {
          reason = "No valid move";
        }

        io.to(roomCode).emit("turn_skipped", {
          dice,
          reason,
          skippedTurn,
          nextTurn: freshGame.currentTurn,
        });

        _startTurnTimer(io, roomCode);
        _scheduleBotTurn(io, roomCode);
        return;
      }

      // Emit dice result so client sees the roll animation
      freshGame.dice = dice;
      await saveGame(roomCode, freshGame);
      io.to(roomCode).emit("dice_result", { dice, turn: freshGame.currentTurn });

      // ── Bot picks and moves token ───────────────────────────
      // Short delay so client can see the dice before the move
      const moveDelay = 1000 + Math.random() * 800;

      setTimeout(async () => {
        const g = await getGame(roomCode);
        if (!g || g.dice === null) return;

        const botColor  = g.players[g.currentTurn].color;
        const bestIndex = _pickBestToken(g, botColor, g.dice);

        if (bestIndex === -1) {
          // Shouldn't happen (hasValidMove was true), but handle gracefully
          const skippedTurn  = g.currentTurn;
          g.dice             = null;
          g.currentTurn      = (g.currentTurn + 1) % g.players.length;
          await saveGame(roomCode, g);

          io.to(roomCode).emit("turn_skipped", {
            dice:        g.dice ?? dice,
            reason:      "No valid move",
            skippedTurn,
            nextTurn:    g.currentTurn,
          });
          _startTurnTimer(io, roomCode);
          _scheduleBotTurn(io, roomCode);
          return;
        }

        await _executeBotMove(io, roomCode, botId, bestIndex);

      }, moveDelay);

    }, thinkDelay);

  } catch (err) {
    console.error("[bot] _handleBotTurn error:", err.message);
  }
}


// Execute the bot's chosen move (mirrors move_token logic)
async function _executeBotMove(io, roomCode, botId, tokenIndex) {
  try {
    const game = await getGame(roomCode);
    if (!game || game.dice === null) return;

    const player = game.players[game.currentTurn];
    if (player.id !== botId) return;

    const color = player.color;
    const dice  = game.dice;
    let   pos   = game.tokens[color][tokenIndex];

    console.log(`[bot] move token[${tokenIndex}] pos=${pos} dice=${dice} (${color})`);

    if (pos === BOARD_SIZE) return;

    // ── Calculate new position ────────────────────────────────
    if (pos === 0) {
      if (dice !== 6) return;
      pos = COLOR_START[color];
    } else {
      const outerTrack  = 52;
      const startPos    = COLOR_START[color];
      const stepsTaken  = (pos - startPos + outerTrack) % outerTrack;
      const stepsToHome = (outerTrack - 1) - stepsTaken;

      if (pos > outerTrack) {
        const newPos = pos + dice;
        if (newPos > BOARD_SIZE) return;
        pos = newPos;
      } else if (dice <= stepsToHome) {
        pos = ((pos - 1 + dice) % outerTrack) + 1;
      } else {
        const homeStep = dice - stepsToHome;
        const newPos   = outerTrack + homeStep;
        if (newPos > BOARD_SIZE) return;
        pos = newPos;
      }
    }

    // If blocked, try alternate token
    if (_isBlocked(game, pos, color)) {
      const altIndex = _findAltToken(game, color, dice, tokenIndex);
      if (altIndex !== -1) {
        return _executeBotMove(io, roomCode, botId, altIndex);
      }
      return; // no valid move
    }

    game.tokens[color][tokenIndex] = pos;

    // ── Capture check ─────────────────────────────────────────
    let captured = false;
    if (pos <= 52 && !SAFE_CELLS.includes(pos)) {
      for (const otherColor of Object.keys(game.tokens)) {
        if (otherColor === color) continue;
        game.tokens[otherColor].forEach((t, i) => {
          if (t === pos) {
            game.tokens[otherColor][i] = 0;
            captured = true;
            console.log(`[bot] captured ${otherColor}[${i}]`);
          }
        });
      }
    }

    // ── Win check ─────────────────────────────────────────────
    if (game.tokens[color].every(t => t === BOARD_SIZE)) {
      console.log(`[bot] BOT WON in room ${roomCode}`);
      game.dice = null;
      await saveGame(roomCode, game);
      io.to(roomCode).emit("game_state", game);

      // Bot wins — no DB balance update, just notify (user lost)
      io.to(roomCode).emit("player_won", {
        player:      botId,
        color,
        newWinCount: null,
        winAmount:   0,
        newBalance:  null,
      });

      _clearTimer(roomCode);
      setTimeout(() => removeGame(roomCode), 30000);
      redis.del(`bot:${roomCode}`).catch(() => {});
      return;
    }

    // ── Bonus turn (dice=6 or capture) ───────────────────────
    const bonusTurn = (dice === 6) || captured;
    if (!bonusTurn) {
      game.currentTurn = (game.currentTurn + 1) % game.players.length;
    }

    game.dice = null;
    await saveGame(roomCode, game);

    io.to(roomCode).emit("game_state", game);
    _startTurnTimer(io, roomCode);
    _scheduleBotTurn(io, roomCode); // check if bot has another bonus turn

  } catch (err) {
    console.error("[bot] _executeBotMove error:", err.message);
  }
}


// Pick the best token for the bot to move
// Priority: reach home > capture > move token in home column > advance farthest token
function _pickBestToken(game, color, dice) {
  const tokens   = game.tokens[color];
  let bestIndex  = -1;
  let bestScore  = -Infinity;

  tokens.forEach((pos, i) => {
    if (pos === BOARD_SIZE) return; // already home — skip

    const newPos = _calcBotNewPos(pos, dice, color);
    if (newPos === null) return; // invalid move
    if (_isBlocked(game, newPos, color)) return; // blocked by own tokens

    let score = 0;

    if (newPos === BOARD_SIZE) {
      score = 10000; // reaching home is always best
    } else {
      // Check if we'd capture an opponent token
      if (newPos <= 52 && !SAFE_CELLS.includes(newPos)) {
        for (const [otherColor, otherTokens] of Object.entries(game.tokens)) {
          if (otherColor === color) continue;
          if (otherTokens.some(t => t === newPos)) {
            score += 500; // capturing is very good
            break;
          }
        }
      }

      // Prefer tokens already in home column (pos > 52)
      if (pos > 52) {
        score += 300 + newPos;
      } else {
        score += newPos; // prefer tokens closer to home
      }

      // Extra: prefer bringing a base token in (dice = 6 + token at 0)
      if (pos === 0 && dice === 6) {
        score += 100;
      }
    }

    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  });

  return bestIndex;
}


// Calculate new position for a token (same math as move_token handler)
function _calcBotNewPos(pos, dice, color) {
  const start      = COLOR_START[color];
  const OUTER      = 52;

  if (pos >= BOARD_SIZE) return null;

  if (pos === 0) {
    return dice === 6 ? start : null;
  }

  if (pos > OUTER) {
    const np = pos + dice;
    return np > BOARD_SIZE ? null : np;
  }

  const stepsTaken  = (pos - start + OUTER) % OUTER;
  const stepsToHome = (OUTER - 1) - stepsTaken;

  if (dice <= stepsToHome) {
    return ((pos - 1 + dice) % OUTER) + 1;
  }

  const homeStep = dice - stepsToHome;
  const np       = OUTER + homeStep;
  return np > BOARD_SIZE ? null : np;
}


// Find an alternate token when the chosen one is blocked
function _findAltToken(game, color, dice, excludeIndex) {
  const tokens = game.tokens[color];
  for (let i = 0; i < tokens.length; i++) {
    if (i === excludeIndex) continue;
    const pos    = tokens[i];
    if (pos === BOARD_SIZE) continue;
    const newPos = _calcBotNewPos(pos, dice, color);
    if (newPos !== null && !_isBlocked(game, newPos, color)) return i;
  }
  return -1;
}


// ═══════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════

function _isBlocked(game, pos, color) {
  if (pos === 0 || pos > 52) return false;
  let count = 0;
  game.tokens[color].forEach(t => { if (t === pos) count++; });
  return count >= 2;
}

function _clearTimer(roomCode) {
  if (timerMap[roomCode]) {
    clearTimeout(timerMap[roomCode]);
    delete timerMap[roomCode];
  }
}

function _startTurnTimer(io, roomCode) {
  _clearTimer(roomCode);
  timerMap[roomCode] = setTimeout(async () => {
    const game = await getGame(roomCode);
    if (!game) return;

    console.log(`[timer] timeout in room ${roomCode}`);

    game.currentTurn = (game.currentTurn + 1) % game.players.length;
    game.dice        = null;
    await saveGame(roomCode, game);

    io.to(roomCode).emit("turn_timeout", { turn: game.currentTurn });
    _startTurnTimer(io, roomCode);
    _scheduleBotTurn(io, roomCode); // ← bot check after timeout too
  }, TURN_TIME);
}

function _log(msg, detail) {
  console.log(`[game.socket] ${msg}`, detail ?? "");
}

// Export for use in matchmaking if needed
module.exports._scheduleBotTurn = _scheduleBotTurn;