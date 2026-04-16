const rouletteService = require("../../services/roulette/roulette.service");

function initRouletteSocket(io) {
  const rouletteNsp = io.of("/roulette");

  rouletteNsp.on("connection", (socket) => {
    console.log("[roulette] player connected:", socket.id);

    let username = "Anonymous";
    let userId   = null;

    // ── Join event (like joinAndarBahar) ──────────────────────
    socket.on("joinRoulette", (data) => {
      if (data && data.username) username = data.username;
      if (data && data.userId)   userId   = data.userId;

      console.log(`[roulette] player joined: ${username} (${userId})`);

      socket.emit("rouletteReady", {
        message: "Ready to play Roulette!",
        // Send wheel info to Flutter on join
        payoutTable: {
          color:  "2x  — red / black / green",
          parity: "2x  — odd / even",
          half:   "2x  — low (1-18) / high (19-36)",
          dozen:  "5x  — 1st / 2nd / 3rd dozen",
          column: "5x  — col1 / col2 / col3",
          number: "19x — single number (0–36)",
        },
      });
    });

    // ── Play event (like playAndarBahar) ──────────────────────
    // payload: { userId, username, bets: [{ betType, betValue, amount }], useFreeSpins }
    socket.on("playRoulette", async (data) => {
      const playerId   = (data && data.userId)      || userId;
      const playerName = (data && data.username)    || username;
      const bets       = (data && data.bets)        || [];
      const useFreeSpins = (data && data.useFreeSpins) || false;

      if (!playerId) {
        return socket.emit("rouletteError", { message: "userId is required" });
      }
      if (!bets || bets.length === 0) {
        return socket.emit("rouletteError", { message: "bets are required" });
      }

      try {
        // Tell Flutter the wheel is spinning
        socket.emit("rouletteSpinning", { message: "Wheel is spinning..." });

        const {
          record, newWinCount, reward, recovery,
          newBalance, totalWin, totalBet, netChange,
          winType, freeSpinUsed, freeSpins,
          spinResult, resultColor, resultParity,
          resultHalf, resultDozen, resultColumn,
          betResults, popularNumber, popularPercent,
        } = await rouletteService.playGame(playerId, playerName, bets, useFreeSpins);

        // Send full result to player
        socket.emit("rouletteResult", {
          data:          record,
          newWinCount,
          reward,
          recovery,
          newBalance,
          totalWin,
          totalBet,
          netChange,
          winType,
          freeSpinUsed,
          freeSpins,
          spinResult,
          resultColor,
          resultParity,
          resultHalf,
          resultDozen,
          resultColumn,
          betResults,
          popularNumber,
          popularPercent,
        });

        // Broadcast jackpot (19x number hit) to all players in namespace
        const hitJackpot = betResults.some(b => b.betType === "number" && b.won);
        if (hitJackpot) {
          rouletteNsp.emit("rouletteJackpot", {
            username:    playerName,
            spinResult,
            totalWin,
          });
        } else if (record.result === "WIN") {
          rouletteNsp.emit("rouletteWinner", {
            username:   playerName,
            spinResult,
            resultColor,
            totalWin,
          });
        }

      } catch (err) {
        console.error("[roulette] play error:", err.message);
        socket.emit("rouletteError", { message: err.message || "Failed to play Roulette" });
      }
    });

    socket.on("disconnect", () => {
      console.log(`[roulette] player disconnected: ${username}`);
    });
  });

  console.log("[roulette] socket namespace /roulette initialized");
}

module.exports = initRouletteSocket;