const crypto = require("crypto");

// ── Super Loto config ─────────────────────────────────────────
const TOTAL_NUMBERS = 49;    // numbers range: 1–49
const PICK_COUNT    = 6;     // player picks 6 numbers per ticket

// ── Prize tiers (by how many numbers matched) ─────────────────
const PRIZE_TIERS = {
  6: { tier: "TIER_0",  label: "All 6 matched!" },
  5: { tier: "TIER_1",   label: "Tier 1 — 5 numbers matched" },
  4: { tier: "TIER_2",   label: "Tier 2 — 4 numbers matched" },
  3: { tier: "TIER_3",   label: "Tier 3 — 3 numbers matched" },
};
// 0, 1, 2 matches = LOSE

// ── Generate winning numbers (cryptographically random) ───────
function drawWinningNumbers() {
  const pool = [];
  for (let i = 1; i <= TOTAL_NUMBERS; i++) pool.push(i);

  const drawn = [];
  for (let i = 0; i < PICK_COUNT; i++) {
    const idx = crypto.randomInt(0, pool.length);
    drawn.push(pool[idx]);
    pool.splice(idx, 1);
  }

  return drawn.sort((a, b) => a - b);
}

// ── Quick Pick: auto-generate random numbers for a player ─────
function quickPick() {
  return drawWinningNumbers();
}

// ── Validate player's chosen numbers ──────────────────────────
function validateNumbers(numbers) {
  if (!Array.isArray(numbers)) return { valid: false, reason: "Numbers must be an array" };
  if (numbers.length !== PICK_COUNT) return { valid: false, reason: `Must pick exactly ${PICK_COUNT} numbers` };

  const unique = new Set(numbers);
  if (unique.size !== PICK_COUNT) return { valid: false, reason: "Numbers must be unique" };

  for (const n of numbers) {
    if (!Number.isInteger(n) || n < 1 || n > TOTAL_NUMBERS) {
      return { valid: false, reason: `Each number must be between 1 and ${TOTAL_NUMBERS}` };
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