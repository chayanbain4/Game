const lotteryService = require("../../services/lottery/lottery.service");
const LotteryEngine  = require("../../game/lottery/lottery.engine");
const drawManager    = require("../../game/lottery/draw.manager");

// POST /api/lottery/start  (still available for admin / manual use)
exports.startDraw = async (req, res) => {
  try {
    const result = await drawManager.triggerManualDraw();

    if (!result.success) {
      return res.status(400).json({ success: false, message: result.message });
    }

    res.json({ success: true, data: result });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/lottery/buy
// drawNumber is now OPTIONAL — service will auto-start a draw if none is open
exports.buyTicket = async (req, res) => {
  try {
    const { userId, username, numbers, drawNumber, useFreeSpins, multiplier } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: "userId is required" });
    }

    // drawNumber is optional: pass null so the service can auto-resolve / auto-start
    const { ticket, reward, recovery, newBalance, freeSpinUsed, freeSpins } =
      await lotteryService.buyTicket(
        userId,
        username,
        numbers,
        drawNumber || null,   // ← no longer required from client
        useFreeSpins,
        multiplier || 1
      );

    res.json({ success: true, data: ticket, reward, recovery, newBalance, freeSpinUsed, freeSpins });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// POST /api/lottery/quick-pick
// drawNumber is now OPTIONAL — service will auto-start a draw if none is open
exports.quickPick = async (req, res) => {
  try {
    const { userId, username, drawNumber, useFreeSpins, multiplier } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: "userId is required" });
    }

    // Pass null numbers → service auto quick-picks; pass null drawNumber → service auto-starts
    const { ticket, reward, recovery, newBalance, freeSpinUsed, freeSpins } =
      await lotteryService.buyTicket(
        userId,
        username,
        null,                 // ← triggers quickPick inside service
        drawNumber || null,   // ← no longer required from client
        useFreeSpins,
        multiplier || 1
      );

    res.json({ success: true, data: ticket, reward, recovery, newBalance, freeSpinUsed, freeSpins });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// GET /api/lottery/current-draw
exports.getCurrentDraw = async (req, res) => {
  try {
    const draw = await lotteryService.getCurrentDraw();

    if (!draw) {
      return res.status(404).json({ success: false, message: "No active draw found" });
    }

    const drawObj = draw.toObject();
    drawObj.remainingTime = drawManager.getRemainingTime();

    res.json({ success: true, data: drawObj });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/lottery/draw/:drawNumber
exports.getDraw = async (req, res) => {
  try {
    const drawNumber = parseInt(req.params.drawNumber);
    const draw = await lotteryService.getDraw(drawNumber);

    if (!draw) {
      return res.status(404).json({ success: false, message: "Draw not found" });
    }

    res.json({ success: true, data: draw });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/lottery/tickets/:userId/:drawNumber
exports.getUserTickets = async (req, res) => {
  try {
    const { userId, drawNumber } = req.params;
    const tickets = await lotteryService.getUserTickets(userId, parseInt(drawNumber));

    res.json({ success: true, data: tickets });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/lottery/history/:userId
exports.getUserHistory = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    const history = await lotteryService.getUserHistory(userId, limit);

    res.json({ success: true, data: history });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/lottery/recent-draws
exports.getRecentDraws = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const draws = await lotteryService.getRecentDraws(limit);

    res.json({ success: true, data: draws });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/lottery/generate-numbers
exports.generateNumbers = (req, res) => {
  const numbers = LotteryEngine.quickPick();
  res.json({ success: true, data: { numbers } });
};