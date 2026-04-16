const express = require("express");
const router  = express.Router();

const rouletteController = require("../../controllers/roulette/roulette.controller");

router.post("/play",              rouletteController.play);
router.get("/history/:userId",    rouletteController.getUserHistory);
router.get("/stats/:userId",      rouletteController.getUserStats);

module.exports = router;