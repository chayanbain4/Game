const jwt = require("jsonwebtoken");
const User = require("../../models/ludo/user.model");
const { JWT_SECRET } = require("../../config/env");

async function guestLogin(deviceId, displayName) {
 let user = await User.findOne({ deviceId });

 if (!user) {
  user = await User.create({ deviceId, displayName });
 }

 const token = jwt.sign({ userId: user._id }, JWT_SECRET);

 return { user, token };
}

module.exports = { guestLogin };