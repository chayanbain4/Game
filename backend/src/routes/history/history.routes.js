const express = require("express");
const router = express.Router();
const historyController = require("../../controllers/history/history.controller");

router.get("/:userId", historyController.getFullHistory);

module.exports = router;
