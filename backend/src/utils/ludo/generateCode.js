const { customAlphabet } = require("nanoid");

const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const nanoid = customAlphabet(alphabet, 6);

function generateCode() {
 return nanoid();
}

module.exports = generateCode;