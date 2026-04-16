const crypto = require("crypto");

// ── Standard European roulette wheel (0–36) ───────────────────
const RED_NUMBERS = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];

// Wheel sequence (physical order on a real roulette wheel)
const WHEEL_SEQUENCE = [
  0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,
  10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26
];

// ── Casino-style bet types & multipliers ──────────────────────
//   color   (red / black / green)  → 2x
//   parity  (odd / even)           → 2x
//   half    (low 1-18 / high 19-36)→ 2x
//   dozen   (1st / 2nd / 3rd)      → 5x
//   column  (col1 / col2 / col3)   → 5x
//   number  (0–36 single number)   → 19x   ← casino jackpot
//
// "multiplier" = total returned (e.g. 2x means you get back 2× your stake)
// payout = total returned (2 = you get back 2x your stake = 1:1 profit)
// All bet types: bet ₹10 → win ₹10 profit → total returned ₹20
const BET_TYPES = {
  color:  { payout: 2 },
  parity: { payout: 2 },
  half:   { payout: 2 },
  dozen:  { payout: 2 },
  column: { payout: 2 },
  number: { payout: 2 },
};

function getColor(num) {
  if (num === 0) return "green";
  return RED_NUMBERS.includes(num) ? "red" : "black";
}

function getParity(num) {
  if (num === 0) return "zero";
  return num % 2 === 0 ? "even" : "odd";
}

function getHalf(num) {
  if (num === 0) return "zero";
  return num <= 18 ? "low" : "high";
}

function getDozen(num) {
  if (num === 0) return "zero";
  if (num <= 12) return "1st";
  if (num <= 24) return "2nd";
  return "3rd";
}

function getColumn(num) {
  if (num === 0) return "zero";
  const col = num % 3;
  if (col === 1) return "col1";
  if (col === 2) return "col2";
  return "col3";
}

// ── Spin the wheel ────────────────────────────────────────────
// playerBets: [{ betType, betValue, amount }]
// forceWin: if true, re-spins up to maxAttempts until at least one bet wins
function spin(playerBets = [], forceWin = false, maxAttempts = 3) {
  let result = null;

  for (let attempt = 0; attempt < (forceWin ? maxAttempts : 1); attempt++) {
    result = _spinOnce();
    if (!forceWin) break;

    const { totalWin } = calculatePayout(playerBets, result);
    if (totalWin > 0) break; // player wins something → done
  }

  return result;
}

function _spinOnce() {
  const num         = crypto.randomInt(0, 37); // 0–36
  const color       = getColor(num);
  const parity      = getParity(num);
  const half        = getHalf(num);
  const dozen       = getDozen(num);
  const column      = getColumn(num);

  return { num, color, parity, half, dozen, column };
}

// ── Calculate payout for all bets ────────────────────────────
// Returns { totalWin, betResults[] }
function calculatePayout(bets, spinResult) {
  let totalWin = 0;
  const betResults = [];

  for (const bet of bets) {
    const { betType, betValue, amount } = bet;
    const payout = BET_TYPES[betType]?.payout || 0;
    let won = false;

    switch (betType) {
      case "color":
        won = betValue === spinResult.color;
        break;
      case "parity":
        won = spinResult.num !== 0 && betValue === spinResult.parity;
        break;
      case "half":
        won = spinResult.num !== 0 && betValue === spinResult.half;
        break;
      case "dozen":
        won = spinResult.num !== 0 && betValue === spinResult.dozen;
        break;
      case "column":
        won = spinResult.num !== 0 && betValue === spinResult.column;
        break;
      case "number":
        won = Number(betValue) === spinResult.num;
        break;
    }

    const winAmount = won ? amount * payout : 0;
    totalWin += winAmount;

    betResults.push({ betType, betValue, amount, won, winAmount, payout: won ? payout : 0 });
  }

  return { totalWin, betResults };
}

// ── Validate a single bet object ─────────────────────────────
function validateBet(bet) {
  const { betType, betValue, amount } = bet;

  if (!BET_TYPES[betType]) return `Invalid betType: ${betType}`;
  if (!amount || amount <= 0) return "Bet amount must be greater than 0";

  switch (betType) {
    case "color":
      if (!["red", "black", "green"].includes(betValue)) return "color must be red, black, or green";
      break;
    case "parity":
      if (!["odd", "even"].includes(betValue)) return "parity must be odd or even";
      break;
    case "half":
      if (!["low", "high"].includes(betValue)) return "half must be low or high";
      break;
    case "dozen":
      if (!["1st", "2nd", "3rd"].includes(betValue)) return "dozen must be 1st, 2nd, or 3rd";
      break;
    case "column":
      if (!["col1", "col2", "col3"].includes(betValue)) return "column must be col1, col2, or col3";
      break;
    case "number":
      if (Number(betValue) < 0 || Number(betValue) > 36) return "number must be 0–36";
      break;
  }
  return null; // valid
}

module.exports = {
  spin,
  calculatePayout,
  validateBet,
  BET_TYPES,
  getColor,
  getParity,
  WHEEL_SEQUENCE,
  RED_NUMBERS,
};