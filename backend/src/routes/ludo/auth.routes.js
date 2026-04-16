const router = require("express").Router();
const { guestLoginController } = require("../../controllers/ludo/auth.controller");

router.post("/guest", guestLoginController);

module.exports = router;