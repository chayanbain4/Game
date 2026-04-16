const dailyReward = require("../../services/engagement/dailyReward");
const User = require("../../models/auth/user.model");

// GET /api/engagement/daily-reward/status
exports.getStatus = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select("email");
    if (!user) return res.status(404).json({ success: false, message: "User not found" });

    const status = await dailyReward.getStatus(user.email);
    return res.json({ success: true, ...status });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/engagement/daily-reward/claim
exports.claim = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select("email");
    if (!user) return res.status(404).json({ success: false, message: "User not found" });

    const result = await dailyReward.claim(user.email);
    return res.json(result);
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
