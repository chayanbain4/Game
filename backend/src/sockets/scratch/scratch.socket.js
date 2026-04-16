const scratchService = require("../../services/scratch/scratch.service");

function initScratchSocket(io) {
  // Use a separate namespace so it doesn't conflict with ludo or number sockets
  const scratchNsp = io.of("/scratch");

  scratchNsp.on("connection", (socket) => {
    console.log("[scratch] player connected:", socket.id);

    let username = "Anonymous";
    let userId = null;

    // ── Player identifies themselves ──────────────────────────
    socket.on("joinScratch", (data) => {
      if (data && data.username) username = data.username;
      if (data && data.userId) userId = data.userId;

      console.log(`[scratch] player joined: ${username} (${userId})`);

      socket.emit("scratchReady", {
        message: "Ready to scratch!",
      });
    });

    // ── Player scratches a card ───────────────────────────────
    socket.on("scratchCard", async (data) => {
      const playerId = (data && data.userId) || userId;
      const playerName = (data && data.username) || username;

      if (!playerId) {
        return socket.emit("scratchError", {
          message: "userId is required",
        });
      }

      try {
        const result = await scratchService.playScratchCard(
          playerId,
          playerName
        );

        // Send result to player
        socket.emit("scratchResult", {
          cells: result.cells,
          result: result.result,
          symbol: result.symbol,
          matchCount: result.matchCount,
          multiplier: result.multiplier,
        });

        // Broadcast win to all connected scratch players
        if (result.result === "WIN") {
          scratchNsp.emit("scratchWinner", {
            username: playerName,
            symbol: result.symbol,
            multiplier: result.multiplier,
          });
        }
      } catch (err) {
        console.error("[scratch] play error:", err.message);
        socket.emit("scratchError", {
          message: "Failed to play scratch card",
        });
      }
    });

    // ── Disconnect ────────────────────────────────────────────
    socket.on("disconnect", () => {
      console.log(`[scratch] player disconnected: ${username}`);
    });
  });

  console.log("[scratch] socket namespace /scratch initialized");
}

module.exports = initScratchSocket;
