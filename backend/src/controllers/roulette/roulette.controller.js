const rouletteService = require("../../services/roulette/roulette.service");

// POST /api/roulette/play
exports.play = async (req, res) => {
  try {
    const { userId, username, bets, useFreeSpins } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: "userId is required" });
    }
    if (!bets || !Array.isArray(bets) || bets.length === 0) {
      return res.status(400).json({ success: false, message: "bets array is required" });
    }

    const {
      record, newWinCount, reward, recovery,
      newBalance, totalWin, totalBet, netChange,
      winType, freeSpinUsed, freeSpins,
      spinResult, resultColor, resultParity,
      resultHalf, resultDozen, resultColumn,
      betResults, popularNumber, popularPercent,
    } = await rouletteService.playGame(userId, username, bets, useFreeSpins);

    const { padGameStats } = require("../../utils/gameStats");
    const gameStats = padGameStats(1, record.result === "WIN" ? 1 : 0);

    res.json({
      success:      true,
      data:         record,
      newWinCount,
      reward,
      recovery,
      newBalance,
      totalWin,
      totalBet,
      netChange,
      winType,
      freeSpinUsed,
      freeSpins,
      spinResult,
      resultColor,
      resultParity,
      resultHalf,
      resultDozen,
      resultColumn,
      betResults,
      popularNumber,
      popularPercent,
      totalPlayers: gameStats.totalPlayers,
      totalWinners: gameStats.totalWinners,
      totalLosers:  gameStats.totalLosers,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/roulette/history/:userId
exports.getUserHistory = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    const history = await rouletteService.getUserHistory(userId, limit);
    res.json({ success: true, data: history });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/roulette/stats/:userId
exports.getUserStats = async (req, res) => {
  try {
    const { userId } = req.params;
    const stats = await rouletteService.getUserStats(userId);
    res.json({ success: true, data: stats });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};