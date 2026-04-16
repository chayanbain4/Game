const express = require("express");
const router = express.Router();

const {
  getJackpots,
  getWelcomeBonusStatus,
  claimWelcomeBonus,
  getRecentWinners,
} = require("../../controllers/engagement/engagement.controller");

const leaderboardCtrl = require("../../controllers/engagement/leaderboard.controller");
const dailyRewardCtrl = require("../../controllers/engagement/dailyReward.controller");
const { getLuckyNumbers } = require("../../utils/luckyNumbers");

const authMiddleware = require("../../middlewares/auth.middleware");

// Public — no auth required
router.get("/jackpots", getJackpots);
router.get("/recent-winners", getRecentWinners);
router.get("/leaderboard", leaderboardCtrl.getLeaderboard);

// Protected — auth required
router.get ("/welcome-bonus",       authMiddleware, getWelcomeBonusStatus);
router.post("/welcome-bonus/claim", authMiddleware, claimWelcomeBonus);

// Daily reward
router.get ("/daily-reward/status", authMiddleware, dailyRewardCtrl.getStatus);
router.post("/daily-reward/claim",  authMiddleware, dailyRewardCtrl.claim);

// Lucky numbers (auth required — needs userId)
router.get("/lucky-numbers", authMiddleware, (req, res) => {
  try {
    const numbers = getLuckyNumbers(req.user.userId);
    res.json({ success: true, numbers });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
