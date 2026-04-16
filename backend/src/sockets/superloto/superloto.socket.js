const drawManager = require("../../game/superloto/draw.manager");

function initSuperLotoSocket(io) {
  const nsp = io.of("/superloto");

  // Initialise the draw manager (restores DB state, does NOT auto-start a loop)
  drawManager.init(io);

  nsp.on("connection", (socket) => {
    console.log(`[superloto] player connected: ${socket.id}`);

    socket.on("joinSuperLoto", () => {
      socket.join("superloto-lobby");

      // Send the current state:
      //   drawNumber > 0 + isDrawActive → a draw is open, send time remaining
      //   isDrawActive false             → idle, waiting for first ticket
      socket.emit("superlotoState", {
        drawNumber:    drawManager.getCurrentDrawNumber(),
        remainingTime: drawManager.getRemainingTime(),
        isDrawActive:  drawManager.isDrawActive(),
      });
    });

    socket.on("disconnect", () => {
      console.log(`[superloto] player disconnected: ${socket.id}`);
    });
  });
}

module.exports = initSuperLotoSocket;