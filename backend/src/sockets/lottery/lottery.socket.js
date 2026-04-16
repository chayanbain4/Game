const {
  startLotteryEngine,
  getCurrentDrawNumber,
  getRemainingTime,
} = require("../../game/lottery/draw.manager");

const lotteryService = require("../../services/lottery/lottery.service");

function initLotterySocket(io) {
  // Use a separate namespace so it doesn't conflict with other games
  const lotteryNsp = io.of("/lottery");

  lotteryNsp.on("connection", (socket) => {
    console.log("[lottery] player connected:", socket.id);

    let username = "Anonymous";
    let userId = null;

    // ── Player joins lottery ──────────────────────────────────
    socket.on("joinLottery", (data) => {
      if (data && data.username) username = data.username;
      if (data && data.userId) userId = data.userId;

      console.log(`[lottery] player joined: ${username} (${userId})`);

      // Send current draw info
      socket.emit("currentDraw", {
        drawNumber: getCurrentDrawNumber(),
        remainingTime: getRemainingTime(),
      });
    });

    // ── Player buys ticket via socket ─────────────────────────
    socket.on("buyTicket", async (data) => {
      const playerId = (data && data.userId) || userId;
      const playerName = (data && data.username) || username;
      const numbers = data && data.numbers;
      const drawNumber = (data && data.drawNumber) || getCurrentDrawNumber();

      if (!playerId) {
        return socket.emit("lotteryError", { message: "userId is required" });
      }

      try {
        const ticket = await lotteryService.buyTicket(
          playerId, playerName, numbers, drawNumber
        );

        socket.emit("ticketPurchased", {
          ticket: {
            _id: ticket._id,
            numbers: ticket.numbers,
            drawNumber: ticket.drawNumber,
            isQuickPick: ticket.isQuickPick,
          },
        });

        // Broadcast ticket count update
        lotteryNsp.emit("ticketCountUpdate", {
          drawNumber,
        });

      } catch (err) {
        console.error("[lottery] buy error:", err.message);
        socket.emit("lotteryError", { message: err.message });
      }
    });

    // ── Quick pick via socket ─────────────────────────────────
    socket.on("quickPick", async (data) => {
      const playerId = (data && data.userId) || userId;
      const playerName = (data && data.username) || username;
      const drawNumber = (data && data.drawNumber) || getCurrentDrawNumber();

      if (!playerId) {
        return socket.emit("lotteryError", { message: "userId is required" });
      }

      try {
        const ticket = await lotteryService.buyTicket(
          playerId, playerName, null, drawNumber
        );

        socket.emit("ticketPurchased", {
          ticket: {
            _id: ticket._id,
            numbers: ticket.numbers,
            drawNumber: ticket.drawNumber,
            isQuickPick: true,
          },
        });

        lotteryNsp.emit("ticketCountUpdate", { drawNumber });

      } catch (err) {
        console.error("[lottery] quick-pick error:", err.message);
        socket.emit("lotteryError", { message: err.message });
      }
    });

    // ── Disconnect ────────────────────────────────────────────
    socket.on("disconnect", () => {
      console.log(`[lottery] player disconnected: ${username}`);
    });
  });

  // Start the automated draw engine
  startLotteryEngine(lotteryNsp);

  console.log("[lottery] socket namespace /lottery initialized");
}

module.exports = initLotterySocket;
