const crypto = require("crypto");

// ── Lottery config ────────────────────────────────────────────
const TOTAL_NUMBERS = 21;    // numbers range: 0–20 (21 numbers)
const PICK_COUNT    = 3;     // player picks 3 numbers per ticket

// ── Prize tiers (by how many numbers matched) ─────────────────
const PRIZE_TIERS = {
  3: { tier: "TIER_1", label: "All 3 matched!" },
  2: { tier: "TIER_2", label: "2 numbers matched" },
};
// 0, 1 matches = LOSE

// ── Generate winning numbers (cryptographically random) ───────
function drawWinningNumbers() {
  const pool = [];
  for (let i = 0; i < TOTAL_NUMBERS; i++) pool.push(i); // 0–20

  const drawn = [];
  for (let i = 0; i < 3; i++) { // draw 3 winning numbers
    const idx = crypto.randomInt(0, pool.length);
    drawn.push(pool[idx]);
    pool.splice(idx, 1);
  }

  return drawn.sort((a, b) => a - b);
}

// ── Quick Pick: auto-generate random numbers for a player ─────
function quickPick() {
  // Pick 3 unique numbers from 0-20 for a player ticket
  const pool = [];
  for (let i = 0; i < TOTAL_NUMBERS; i++) pool.push(i);
  const picks = [];
  for (let i = 0; i < PICK_COUNT; i++) {
    const idx = crypto.randomInt(0, pool.length);
    picks.push(pool[idx]);
    pool.splice(idx, 1);
  }
  return picks.sort((a, b) => a - b);
}

// ── Validate player's chosen numbers ──────────────────────────
function validateNumbers(numbers) {
  if (!Array.isArray(numbers)) return { valid: false, reason: "Numbers must be an array" };
  if (numbers.length !== PICK_COUNT) return { valid: false, reason: `Must pick exactly ${PICK_COUNT} numbers` };

  const unique = new Set(numbers);
  if (unique.size !== PICK_COUNT) return { valid: false, reason: "Numbers must be unique" };

  for (const n of numbers) {
    if (!Number.isInteger(n) || n < 0 || n > TOTAL_NUMBERS - 1) {
      return { valid: false, reason: `Each number must be between 0 and ${TOTAL_NUMBERS - 1}` };
    }
  }

  return { valid: true };
}

// ── Check how many numbers match ──────────────────────────────
function checkTicket(playerNumbers, winningNumbers) {
  const winSet = new Set(winningNumbers);
  const matched = playerNumbers.filter(n => winSet.has(n));
  const matchCount = matched.length;

  const prize = PRIZE_TIERS[matchCount] || null;

  return {
    playerNumbers: playerNumbers.sort((a, b) => a - b),
    winningNumbers,
    matchedNumbers: matched.sort((a, b) => a - b),
    matchCount,
    result: prize ? "WIN" : "LOSE",
    tier: prize ? prize.tier : null,
    tierLabel: prize ? prize.label : "Better luck next time",
  };
}

module.exports = {
  drawWinningNumbers,
  quickPick,
  validateNumbers,
  checkTicket,
  TOTAL_NUMBERS,
  PICK_COUNT,
  PRIZE_TIERS,
};