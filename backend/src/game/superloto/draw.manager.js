const SuperLotoDraw    = require("../../models/superloto/superlotoDraw.model");
const superlotoService = require("../../services/superloto/superloto.service");
const { padGameStats } = require("../../utils/gameStats");

// ── Config ────────────────────────────────────────────────────
// How long (seconds) the ticket-buying window stays open after
// the FIRST ticket is purchased.  After this window the draw fires.
const TICKET_WINDOW = 20;   // 2 minutes

let currentDrawNumber = 0;
let isRunning         = false;   // true while a draw cycle is active
let drawStartTime     = null;
let _io               = null;    // stored once by init()

// ─────────────────────────────────────────────────────────────────────────────
// Call this once from the socket module, passing the shared io instance.
// Restores draw number from the DB but does NOT auto-start any loop.
// ─────────────────────────────────────────────────────────────────────────────
async function init(io) {
  _io = io;

  try {
    const lastDraw = await SuperLotoDraw.findOne().sort({ drawNumber: -1 });
    if (lastDraw) {
      currentDrawNumber = lastDraw.drawNumber;
      console.log(`[superloto] restored draw counter — last draw #${currentDrawNumber}`);

      // If server was killed mid-draw, close it out now so the DB is clean.
      if (lastDraw.status === "OPEN") {
        try {
          await superlotoService.executeDraw(lastDraw.drawNumber);
          console.log(`[superloto] cleaned up stale OPEN draw #${lastDraw.drawNumber}`);
        } catch (_) { /* already drawn */ }
        isRunning = false;
      }
    }
  } catch (err) {
    console.error("[superloto] init error:", err.message);
  }

  console.log("[superloto] draw manager ready — waiting for first ticket purchase");
}

// ─────────────────────────────────────────────────────────────────────────────
// Call this from the controller every time a ticket is successfully purchased.
// If a draw is already open, it's a no-op.
// If no draw is active, it creates one and starts the countdown.
// ─────────────────────────────────────────────────────────────────────────────
async function ensureDrawActive() {
  if (isRunning) {
    // Draw already in progress — nothing to do
    console.log(`[superloto] draw #${currentDrawNumber} already running, ticket added`);
    return;
  }

  if (!_io) {
    console.error("[superloto] ensureDrawActive called before init()");
    return;
  }

  isRunning     = true;
  drawStartTime = Date.now();
  currentDrawNumber++;

  console.log(`[superloto] first ticket purchased — starting draw #${currentDrawNumber} (${TICKET_WINDOW}s window)`);

  // Create the draw record
  try {
    await SuperLotoDraw.create({
      drawNumber:     currentDrawNumber,
      winningNumbers: [],
      status:         "OPEN",
    });
  } catch (err) {
    if (err.code === 11000) {
      // Duplicate key — bump number and retry once
      currentDrawNumber++;
      try {
        await SuperLotoDraw.create({
          drawNumber:     currentDrawNumber,
          winningNumbers: [],
          status:         "OPEN",
        });
        console.log(`[superloto] draw number bumped to #${currentDrawNumber}`);
      } catch (err2) {
        console.error("[superloto] failed to create draw:", err2.message);
        isRunning = false;
        return;
      }
    } else {
      console.error("[superloto] failed to create draw:", err.message);
      isRunning = false;
      return;
    }
  }

  // Broadcast: draw is now open
  _io.emit("superlotoDrawOpen", {
    drawNumber:  currentDrawNumber,
    ticketWindow: TICKET_WINDOW,
  });

  // Schedule the draw after the ticket window expires
  const drawNum = currentDrawNumber;
  setTimeout(() => _executeDraw(drawNum), TICKET_WINDOW * 1000);
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: execute the draw, emit results, then reset to idle.
// ─────────────────────────────────────────────────────────────────────────────
async function _executeDraw(drawNum) {
  console.log(`[superloto] draw #${drawNum} — executing now`);

  try {
    const result    = await superlotoService.executeDraw(drawNum);
    const gameStats = padGameStats(result.totalTickets, result.totalWinners);

    console.log(`[superloto] draw #${drawNum} result:`, result.winningNumbers);
    console.log(`[superloto] ${result.totalWinners} winners / ${result.totalTickets} tickets`);

    _io.emit("superlotoDrawResult", {
      drawNumber:   result.drawNumber,
      winningNumbers: result.winningNumbers,
      totalTickets: gameStats.totalPlayers,
      totalWinners: gameStats.totalWinners,
      totalLosers:  gameStats.totalLosers,
      winType:      result.winType,
    });
  } catch (err) {
    console.error("[superloto] draw execution error:", err.message);
    _io.emit("superlotoError", { message: "Draw failed. Buy a ticket to start the next one." });
  }

  // ── Reset to idle — next ticket purchase will trigger a new draw ──
  isRunning     = false;
  drawStartTime = null;
  console.log(`[superloto] draw #${drawNum} complete — engine idle, waiting for next ticket`);
}

// ── Helpers used by the controller / socket ───────────────────
function getCurrentDrawNumber() { return currentDrawNumber; }
function isDrawActive()         { return isRunning; }

function getRemainingTime() {
  if (!drawStartTime || !isRunning) return 0;
  const elapsed   = Math.floor((Date.now() - drawStartTime) / 1000);
  const remaining = TICKET_WINDOW - elapsed;
  return remaining > 0 ? remaining : 0;
}

module.exports = {
  init,
  ensureDrawActive,
  getCurrentDrawNumber,
  getRemainingTime,
  isDrawActive,
  TICKET_WINDOW,
};