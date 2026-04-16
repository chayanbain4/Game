const express = require("express");
const router = express.Router();

const andarBaharController = require("../../controllers/andarbahar/andarbahar.controller");

router.post("/play", andarBaharController.play);
router.get("/history/:userId", andarBaharController.getUserHistory);
router.get("/stats/:userId", andarBaharController.getUserStats);

module.exports = router;
