const APP_UPDATE_CONFIG = require('../config/appUpdate.config');


const getAppVersionInfo = async (req, res) => {
  try {
    const platform = (req.query.platform || 'android').toLowerCase();
    const currentVersion = req.query.version || '';

    const config = APP_UPDATE_CONFIG[platform];

    if (!config) {
      return res.status(400).json({ success: false, message: 'Invalid platform' });
    }

    // ✅ KEY FIX - if already on latest, never force update
    const alreadyUpdated = currentVersion === config.latestVersion;
    const forceUpdate = alreadyUpdated ? false : config.forceUpdate;

    return res.status(200).json({
      success: true,
      platform,
      currentVersion,
      latestVersion: config.latestVersion,
      minRequiredVersion: config.minRequiredVersion,
      forceUpdate,
      message: config.message,
      apkUrl: config.apkUrl,
    });

  } catch (error) {
    console.error('App version check error:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch app version info' });
  }
};

module.exports = { getAppVersionInfo };