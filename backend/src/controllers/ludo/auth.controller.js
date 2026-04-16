const { guestLogin } = require("../../services/ludo/auth.service");

async function guestLoginController(req, res) {
  const { deviceId, displayName } = req.body || {};   // safe destructuring

  const data = await guestLogin(deviceId, displayName);

  res.json(data);
}

module.exports = { guestLoginController };