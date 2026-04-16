const LotteryDraw   = require("../../models/lottery/lotteryDraw.model");
const lotteryService = require("../../services/lottery/lottery.service");

const TICKET_WINDOW = 30;  // 30 seconds manual window

let currentDrawNumber = 0;
let isRunning         = false;
let drawStartTime     = null;
let lotteryIo         = null;

async function startLotteryEngine(io) {
  lotteryIo = io;
  try {
    const lastDraw = await LotteryDraw.findOne().sort({ drawNumber: -1 });
    if (lastDraw) {
      currentDrawNumber = lastDraw.drawNumber;
      console.log(`[lottery] initialized at draw #${currentDrawNumber}`);

      if (lastDraw.status === "OPEN") {
        try {
          await lotteryService.executeDraw(lastDraw.drawNumber);
        } catch (_) { }
      }
    }
  } catch (err) {
    console.error("[lottery] failed to read last draw:", err.message);
  }
  console.log("[lottery] manual draw engine ready");
}

async function triggerManualDraw() {
  if (isRunning) return { success: false, message: "A draw is already running" };
  
  isRunning = true;
  currentDrawNumber++;
  drawStartTime = Date.now();

  console.log(`[lottery] Draw #${currentDrawNumber} — OPEN (Manual Start)`);

  try {
    await LotteryDraw.create({
      drawNumber: currentDrawNumber,
      winningNumbers: [],
      status: "OPEN",
    });
  } catch (err) {
    isRunning = false;
    return { success: false, message: "Failed to start draw" };
  }

  if (lotteryIo) {
    lotteryIo.emit("lotteryDrawOpen", {
      drawNumber: currentDrawNumber,
      ticketWindow: TICKET_WINDOW,
    });
  }

  const drawNum = currentDrawNumber;
  setTimeout(async () => {
    console.log(`[lottery] Draw #${drawNum} — DRAWING...`);
    try {
      const result = await lotteryService.executeDraw(drawNum);
      if (lotteryIo) {
        lotteryIo.emit("lotteryDrawResult", {
          drawNumber: result.drawNumber,
          winningNumbers: result.winningNumbers,
          totalTickets: result.totalTickets,
          totalWinners: result.totalWinners,
          winType: result.winType,
        });
      }
    } catch (err) {
      console.error("[lottery] draw execution error:", err.message);
    }
    isRunning = false;
    drawStartTime = null;

  }, TICKET_WINDOW * 1000);

  return { success: true, drawNumber: currentDrawNumber, remainingTime: TICKET_WINDOW };
}

function getCurrentDrawNumber() { return currentDrawNumber; }

function getRemainingTime() {
  if (!isRunning || !drawStartTime) return 0;
  const elapsed = Math.floor((Date.now() - drawStartTime) / 1000);
  const remaining = TICKET_WINDOW - elapsed;
  return remaining > 0 ? remaining : 0;
}

module.exports = {
  startLotteryEngine,
  triggerManualDraw,
  getCurrentDrawNumber,
  getRemainingTime,
};