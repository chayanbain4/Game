const superlotoService = require("../../services/superloto/superloto.service");
const SuperLotoEngine  = require("../../game/superloto/superloto.engine");
const drawManager      = require("../../game/superloto/draw.manager");

const ALLOWED_MULTIPLIERS = [1, 2, 5, 10];

// POST /api/superloto/buy
exports.buyTicket = async (req, res) => {
  try {
    const { userId, username, numbers, useFreeSpins, multiplier } = req.body;
    if (!userId) return res.status(400).json({ success: false, message: "userId is required" });

    const mult = ALLOWED_MULTIPLIERS.includes(Number(multiplier)) ? Number(multiplier) : 1;

    await drawManager.ensureDrawActive();
    const drawNumber = drawManager.getCurrentDrawNumber();

    const { ticket, reward, newBalance, freeSpinUsed, freeSpins, fee } =
      await superlotoService.buyTicket(userId, username, numbers, drawNumber, useFreeSpins, mult);

    return res.json({
      success: true,
      data: ticket,
      reward,
      newBalance,
      freeSpinUsed,
      freeSpins,
      drawNumber,
      remainingTime: drawManager.getRemainingTime(),
      multiplier: mult,
      fee,
    });
  } catch (err) {
    return res.status(400).json({ success: false, message: err.message });
  }
};

// POST /api/superloto/quick-pick
exports.quickPick = async (req, res) => {
  try {
    const { userId, username, useFreeSpins, multiplier } = req.body;
    if (!userId) return res.status(400).json({ success: false, message: "userId is required" });

    const mult = ALLOWED_MULTIPLIERS.includes(Number(multiplier)) ? Number(multiplier) : 1;

    await drawManager.ensureDrawActive();
    const drawNumber = drawManager.getCurrentDrawNumber();

    const { ticket, reward, newBalance, freeSpinUsed, freeSpins, fee } =
      await superlotoService.buyTicket(userId, username, null, drawNumber, useFreeSpins, mult);

    return res.json({
      success: true,
      data: ticket,
      reward,
      newBalance,
      freeSpinUsed,
      freeSpins,
      drawNumber,
      remainingTime: drawManager.getRemainingTime(),
      multiplier: mult,
      fee,
    });
  } catch (err) {
    return res.status(400).json({ success: false, message: err.message });
  }
};

// GET /api/superloto/current-draw
exports.getCurrentDraw = async (req, res) => {
  try {
    if (!drawManager.isDrawActive()) {
      return res.status(404).json({
        success: false,
        message: "No active draw. Buy a ticket to start one!",
        idle: true,
      });
    }
    const draw = await superlotoService.getCurrentDraw();
    if (!draw) {
      return res.status(404).json({ success: false, message: "No active draw found", idle: true });
    }
    const drawObj         = draw.toObject();
    drawObj.remainingTime = drawManager.getRemainingTime();
    drawObj.isDrawActive  = true;
    return res.json({ success: true, data: drawObj });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/superloto/draw/:drawNumber
exports.getDraw = async (req, res) => {
  try {
    const draw = await superlotoService.getDraw(parseInt(req.params.drawNumber));
    if (!draw) return res.status(404).json({ success: false, message: "Draw not found" });
    return res.json({ success: true, data: draw });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/superloto/tickets/:userId/:drawNumber
exports.getUserTickets = async (req, res) => {
  try {
    const { userId, drawNumber } = req.params;
    const tickets = await superlotoService.getUserTickets(userId, parseInt(drawNumber));
    return res.json({ success: true, data: tickets });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/superloto/history/:userId
exports.getUserHistory = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit   = parseInt(req.query.limit) || 20;
    const history = await superlotoService.getUserHistory(userId, limit);
    return res.json({ success: true, data: history });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/superloto/recent-draws
exports.getRecentDraws = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const draws = await superlotoService.getRecentDraws(limit);
    return res.json({ success: true, data: draws });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/superloto/generate-numbers
exports.generateNumbers = (req, res) => {
  const numbers = SuperLotoEngine.quickPick();
  return res.json({ success: true, data: { numbers } });
};

// GET /api/superloto/status
exports.getStatus = (req, res) => {
  return res.json({
    success: true,
    data: {
      isDrawActive:  drawManager.isDrawActive(),
      drawNumber:    drawManager.getCurrentDrawNumber(),
      remainingTime: drawManager.getRemainingTime(),
    },
  });
};