const express = require("express");
const router = express.Router();

const scratchController = require("../../controllers/scratch/scratch.controller");

router.post("/play", scratchController.play);
router.get("/history", scratchController.getHistory);
router.get("/history/:userId", scratchController.getUserHistory);

module.exports = router;
