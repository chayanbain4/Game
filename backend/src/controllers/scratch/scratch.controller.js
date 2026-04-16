const scratchService = require("../../services/scratch/scratch.service");

// POST /api/scratch/play
exports.play = async (req, res) => {
  try {
    // 1. Extract the new multiplier field from the request body
    const { userId, username, useFreeSpins, multiplier } = req.body;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "userId is required",
      });
    }

    // 2. Parse and validate the multiplier (default to 1x if missing)
    const parsedMultiplier = parseInt(multiplier) || 1;
    const allowedMultipliers = [1, 2, 5, 10];
    
    if (!allowedMultipliers.includes(parsedMultiplier)) {
      return res.status(400).json({
        success: false,
        message: "Invalid multiplier. Allowed values are 1, 2, 5, or 10.",
      });
    }

    // 3. Pass the parsedMultiplier to the service layer
    const { 
      record, 
      newWinCount, 
      reward, 
      newBalance, 
      winAmount, 
      freeSpinUsed, 
      freeSpins 
    } = await scratchService.playScratchCard(
      userId, 
      username, 
      useFreeSpins, 
      parsedMultiplier // Added here!
    );

    const { padGameStats } = require("../../utils/gameStats");
    const gameStats = padGameStats(1, record.result === "WIN" ? 1 : 0);

    res.json({
      success: true,
      data: record,
      newWinCount,
      reward,
      newBalance,
      winAmount,
      freeSpinUsed,
      freeSpins,
      totalPlayers: gameStats.totalPlayers,
      totalWinners: gameStats.totalWinners,
      totalLosers: gameStats.totalLosers,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// GET /api/scratch/history
exports.getHistory = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const history = await scratchService.getHistory(limit);

    res.json({
      success: true,
      data: history,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// GET /api/scratch/history/:userId
exports.getUserHistory = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    const history = await scratchService.getUserHistory(userId, limit);

    res.json({
      success: true,
      data: history,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};