const User = require("../../models/auth/user.model");

// ── Early Positive Experience ─────────────────────────────────────────────────
// New users get boosted wins in their first THRESHOLD games PER GAME.
// Playing Number Game 10 times does NOT consume the Andar Bahar or Scratch boost.
// Each game passes its own field name so the counter is tracked independently.

const EARLY_GAME_THRESHOLD = 3;

/**
 * Check whether a user is still in the early-experience window for a specific game.
 *
 * @param {string} email      - user email (used as userId throughout the app)
 * @param {string} gameField  - the per-game played field to check, e.g. 'scratchGamesPlayed'
 *                              Defaults to legacy 'totalGamesPlayed' for backward compat.
 * @returns {boolean} true if the user should receive a boosted result
 */
async function shouldBoost(email, gameField = "totalGamesPlayed") {
  if (!email) return false;
  const user = await User.findOne({ email: String(email).trim().toLowerCase() })
    .select(gameField)
    .lean();
  if (!user) return false;
  return (user[gameField] || 0) < EARLY_GAME_THRESHOLD;
}

/**
 * Increment the per-game played counter by 1.
 * Call this AFTER each game round regardless of outcome.
 * Also increments the global totalGamesPlayed for stats/leaderboard use.
 *
 * @param {string} email      - user email
 * @param {string} gameField  - the per-game played field to increment, e.g. 'scratchGamesPlayed'
 *                              Defaults to legacy 'totalGamesPlayed'.
 */
async function incrementGamesPlayed(email, gameField = "totalGamesPlayed") {
  if (!email) return;
  const inc = { totalGamesPlayed: 1 };
  // Also increment the specific game field if it's different from the global one
  if (gameField !== "totalGamesPlayed") {
    inc[gameField] = 1;
  }
  await User.updateOne(
    { email: String(email).trim().toLowerCase() },
    { $inc: inc }
  );
}

module.exports = {
  shouldBoost,
  incrementGamesPlayed,
  EARLY_GAME_THRESHOLD,
};