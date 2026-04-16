/**
 * Lucky Numbers — per-user, per-day deterministic numbers (1-49).
 * Generated from a hash of date + userId so they're stable all day
 * but different per user. Served from backend so both client & server
 * agree on the same set (used for Lucky Bonus in lottery/superloto).
 */

// Simple deterministic hash
function hashCode(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) {
    h = ((h * 31) + str.charCodeAt(i)) & 0x7FFFFFFF;
  }
  return h;
}

// LCG pseudo-random from seed
function nextRand(seed) {
  return ((seed * 1103515245) + 12345) & 0x7FFFFFFF;
}

/**
 * Returns an array of 3 sorted lucky numbers (1-49) for the given userId today.
 */
function getLuckyNumbers(userId) {
  const today = new Date();
  const dateKey = `${today.getFullYear()}-${today.getMonth()}-${today.getDate()}`;
  let seed = hashCode(`${dateKey}:${userId}`);

  const nums = new Set();
  while (nums.size < 3) {
    seed = nextRand(seed);
    nums.add((seed % 49) + 1);
  }
  return [...nums].sort((a, b) => a - b);
}

module.exports = { getLuckyNumbers };
