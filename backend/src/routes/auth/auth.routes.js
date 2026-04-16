const express = require("express");
const router = express.Router();

const {
  register,
  verifyOtp,
  resendOtp,
  login,
  getStats,
} = require("../../controllers/auth/auth.controller");

const authMiddleware = require("../../middlewares/auth.middleware");

router.post("/register", register);
router.post("/verify-otp", verifyOtp);
router.post("/resend-otp", resendOtp);
router.post("/login", login);

// Returns wins count for the logged-in user
router.get("/stats", authMiddleware, getStats);

router.get("/test", (req, res) => {
  res.json({ success: true, message: "Auth routes working" });
});

module.exports = router;