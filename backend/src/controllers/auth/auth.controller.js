// src/controllers/auth/auth.controller.js
const authService = require("../../services/auth/auth.service");
const User        = require("../../models/auth/user.model");

const register = async (req, res) => {
  try {
    const { name, number, email, password } = req.body;

    if (!name || !number || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "All fields are required",
      });
    }

    const result = await authService.registerUser({ name, number, email, password });

    return res.status(201).json({ success: true, ...result });
  } catch (error) {
    return res.status(400).json({ success: false, message: error.message });
  }
};

const verifyOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: "Email and OTP are required" });
    }

    const result = await authService.verifyUserOtp({ email, otp });

    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    return res.status(400).json({ success: false, message: error.message });
  }
};

const resendOtp = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: "Email is required" });
    }

    const result = await authService.resendOtp({ email });

    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    return res.status(400).json({ success: false, message: error.message });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: "Email and password are required" });
    }

    const result = await authService.loginUser({ email, password });

    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    return res.status(400).json({ success: false, message: error.message });
  }
};

// ── GET /auth/stats ──────────────────────────────────────────────
// Protected by authMiddleware — req.user has { userId, email }
// Returns the current user's win count from the database.
const getStats = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select("wins balance welcomeBonusClaimed name email gamesSinceLastReward dailyRewardStreak lastDailyRewardDate freeSpins");

    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    const today = new Date().toISOString().slice(0, 10);
    const claimedToday = user.lastDailyRewardDate === today;

    return res.status(200).json({
      success: true,
      wins: user.wins,
      balance: user.balance,
      welcomeBonusClaimed: user.welcomeBonusClaimed,
      name:  user.name,
      email: user.email,
      gamesSinceLastReward: user.gamesSinceLastReward || 0,
      rewardThreshold: 3,
      dailyRewardStreak: user.dailyRewardStreak || 0,
      dailyRewardClaimedToday: claimedToday,
      freeSpins: user.freeSpins || 0,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  register,
  verifyOtp,
  resendOtp,
  login,
  getStats,
};