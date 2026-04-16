const engagementService = require("../../services/engagement/engagement.service");

// GET /api/engagement/jackpots
exports.getJackpots = async (_req, res) => {
  try {
    const jackpots = await engagementService.getActiveJackpots();

    res.json({
      success: true,
      data: jackpots,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// GET /api/engagement/welcome-bonus (auth required)
exports.getWelcomeBonusStatus = async (req, res) => {
  try {
    const data = await engagementService.getWelcomeBonusStatus(req.user.userId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// POST /api/engagement/welcome-bonus/claim (auth required)
exports.claimWelcomeBonus = async (req, res) => {
  try {
    const data = await engagementService.claimWelcomeBonus(req.user.userId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// GET /api/engagement/recent-winners (public)
exports.getRecentWinners = async (_req, res) => {
  try {
    const data = await engagementService.getRecentWinners();
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
