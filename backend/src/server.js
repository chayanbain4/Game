require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");

const app            = require("./app");
const connectDB      = require("./config/database");
const { connectRedis } = require("./config/redis");
const { PORT }       = require("./config/env");

const initLudoSocket    = require("./sockets/ludo/socket");
const initNumberSocket  = require("./sockets/number/number.socket");
const initScratchSocket = require("./sockets/scratch/scratch.socket");
const initLotterySocket = require("./sockets/lottery/lottery.socket");
const initSuperLotoSocket = require("./sockets/superloto/superloto.socket");
const initAndarBaharSocket = require("./sockets/andarbahar/andarbahar.socket");
const engagementService    = require("./services/engagement/engagement.service");

async function start() {
  try {
    await connectDB();
    await connectRedis();

    // Seed default jackpots if collection is empty
    await engagementService.seedDefaults();

    const server = http.createServer(app);

    // ONE Socket.io instance — shared across all socket modules
    const io = new Server(server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"],
      },
    });

    initLudoSocket(io);      // passes io — NOT server
    initNumberSocket(io);
    initScratchSocket(io);
    initLotterySocket(io);
    initSuperLotoSocket(io);
    initAndarBaharSocket(io);

    server.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`Health: http://localhost:${PORT}/health`);
    });
  } catch (err) {
    console.error("Server startup error:", err);
    process.exit(1);
  }
}

start();