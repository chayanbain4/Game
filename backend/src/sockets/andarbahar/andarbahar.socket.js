const andarBaharService = require("../../services/andarbahar/andarbahar.service");

function initAndarBaharSocket(io) {
  const abNsp = io.of("/andarbahar");

  abNsp.on("connection", (socket) => {
    console.log("[andarbahar] player connected:", socket.id);

    let username = "Anonymous";
    let userId = null;

    socket.on("joinAndarBahar", (data) => {
      if (data && data.username) username = data.username;
      if (data && data.userId) userId = data.userId;

      console.log(`[andarbahar] player joined: ${username} (${userId})`);

      socket.emit("andarBaharReady", {
        message: "Ready to play Andar Bahar!",
      });
    });

    socket.on("playAndarBahar", async (data) => {
      const playerId   = (data && data.userId)   || userId;
      const playerName = (data && data.username)  || username;
      const choice     = (data && data.choice)    || "";

      if (!playerId) {
        return socket.emit("andarBaharError", {
          message: "userId is required",
        });
      }

      if (!choice) {
        return socket.emit("andarBaharError", {
          message: "choice (ANDAR or BAHAR) is required",
        });
      }

      try {
        const { record, newWinCount } = await andarBaharService.playGame(
          playerId,
          playerName,
          choice
        );

        socket.emit("andarBaharResult", {
          data: record,
          newWinCount,
        });

        if (record.result === "WIN") {
          abNsp.emit("andarBaharWinner", {
            username: playerName,
            winningSide: record.winningSide,
          });
        }
      } catch (err) {
        console.error("[andarbahar] play error:", err.message);
        socket.emit("andarBaharError", {
          message: "Failed to play Andar Bahar",
        });
      }
    });

    socket.on("disconnect", () => {
      console.log(`[andarbahar] player disconnected: ${username}`);
    });
  });

  console.log("[andarbahar] socket namespace /andarbahar initialized");
}

module.exports = initAndarBaharSocket;
