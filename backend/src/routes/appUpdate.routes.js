const express = require('express');
const router = express.Router();

const { getAppVersionInfo } = require('../controllers/appUpdate.controller');

router.get('/app-version', getAppVersionInfo);

module.exports = router;