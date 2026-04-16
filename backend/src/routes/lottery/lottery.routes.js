const express = require("express");
const router  = express.Router();

const lotteryController = require("../../controllers/lottery/lottery.controller");

// Ticket operations
router.post("/buy",        lotteryController.buyTicket);
router.post("/quick-pick", lotteryController.quickPick);

// Draw info
router.get("/current-draw",      lotteryController.getCurrentDraw);
router.get("/draw/:drawNumber",  lotteryController.getDraw);
router.get("/recent-draws",      lotteryController.getRecentDraws);

// User data
router.get("/tickets/:userId/:drawNumber", lotteryController.getUserTickets);
router.get("/history/:userId",             lotteryController.getUserHistory);
router.post("/start", lotteryController.startDraw);
// Helper
router.get("/generate-numbers", lotteryController.generateNumbers);

module.exports = router;
