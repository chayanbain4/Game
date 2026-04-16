const router = require("express").Router();
const auth = require("../../middlewares/auth.middleware");
const {
 createRoomController,
 getRoomController
} = require("../../controllers/ludo/room.controller");

router.post("/", auth, createRoomController);
router.get("/:code", getRoomController);

module.exports = router;