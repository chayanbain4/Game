const express = require("express")
const router = express.Router()

const numberController = require("../../controllers/number/number.controller")

router.post("/play", numberController.play)

module.exports = router