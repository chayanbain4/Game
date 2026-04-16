const express = require("express");
const router  = express.Router();
const ctrl    = require("../../controllers/superloto/superloto.controller");

router.post("/buy",          ctrl.buyTicket);
router.post("/quick-pick",   ctrl.quickPick);

router.get("/status",                      ctrl.getStatus);
router.get("/current-draw",                ctrl.getCurrentDraw);
router.get("/draw/:drawNumber",            ctrl.getDraw);
router.get("/recent-draws",                ctrl.getRecentDraws);
router.get("/tickets/:userId/:drawNumber", ctrl.getUserTickets);
router.get("/history/:userId",             ctrl.getUserHistory);
router.get("/generate-numbers",            ctrl.generateNumbers);

module.exports = router;