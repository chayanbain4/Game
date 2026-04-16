const andarBaharService = require("../../services/andarbahar/andarbahar.service");

// POST /api/andarbahar/play
exports.play = async (req, res) => {
  try {
    const { userId, username, choice, useFreeSpins } = req.body;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "userId is required",
      });
    }

    if (!choice) {
      return res.status(400).json({
        success: false,
        message: "choice (ANDAR or BAHAR) is required",
      });
    }

    const { record, newWinCount, reward, recovery, newBalance, winAmount, winType, freeSpinUsed, freeSpins, popularChoice, popularPercent } = await andarBaharService.playGame(
      userId,
      username,
      choice,
      useFreeSpins
    );

    const { padGameStats } = require("../../utils/gameStats");
    const gameStats = padGameStats(1, record.result === "WIN" ? 1 : 0);

    res.json({
      success: true,
      data: record,
      newWinCount,
      reward,
      recovery,
      newBalance,
      winAmount,
      winType,
      freeSpinUsed,
      freeSpins,
      popularChoice,
      popularPercent,
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

// GET /api/andarbahar/history/:userId
exports.getUserHistory = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    const history = await andarBaharService.getUserHistory(userId, limit);

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

// GET /api/andarbahar/stats/:userId
exports.getUserStats = async (req, res) => {
  try {
    const { userId } = req.params;
    const stats = await andarBaharService.getUserStats(userId);

    res.json({
      success: true,
      data: stats,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};
