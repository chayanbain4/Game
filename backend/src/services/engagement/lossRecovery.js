const User = require("../../models/auth/user.model");

// ── IMPORTANT: must be HIGHER than the attraction burst trigger (7) ───────────
// round.manager.js fires a forced win at lossStreak >= 7.
// This threshold must be > 7 so the streak is never reset by a free-ticket
// before the attraction burst gets a chance to fire.
// Flow: 1→2→3→4→5→6→7 (attraction burst fires, resets to 0) → free ticket
// never fires because streak is reset at 7 first.
// If you change the attraction trigger in round.manager.js, update this too.
const LOSS_STREAK_THRESHOLD = 8;

/**
 * Called after each game result.
 * On win  → resets lossStreak to 0.
 * On loss → increments lossStreak; if it hits threshold (8), awards a free
 *           ticket and resets streak.
 *
 * NOTE: The number game's attraction burst (round.manager.js) fires at 7
 * consecutive losses and resets lossStreak to 0 — so in practice this
 * threshold of 8 is a safety net for other games (scratch, andarbahar, etc.)
 *
 * @param {string} email   – user email (normalised)
 * @param {boolean} didWin – true if user won the game
 * @returns {object|null}  – recovery reward object, or null
 */
async function checkLossRecovery(email, didWin = false) {
  if (!email) return null;
  const normalizedEmail = String(email).trim().toLowerCase();

  if (didWin) {
    await User.updateOne(
      { email: normalizedEmail },
      { $set: { lossStreak: 0 } }
    );
    return null;
  }

  // Increment loss streak
  const user = await User.findOneAndUpdate(
    { email: normalizedEmail },
    { $inc: { lossStreak: 1 } },
    { new: true, select: "lossStreak freeSpins" }
  );

  if (!user) return null;

  if (user.lossStreak >= LOSS_STREAK_THRESHOLD) {
    // Award free ticket and reset streak
    await User.updateOne(
      { email: normalizedEmail },
      { $set: { lossStreak: 0 }, $inc: { freeSpins: 1 } }
    );

    console.log(`[lossRecovery] ${normalizedEmail} hit ${LOSS_STREAK_THRESHOLD} losses – free ticket awarded`);

    return {
      type: "freeTicket",
      message: "Bad luck today! Here is a free ticket.",
      lossStreak: LOSS_STREAK_THRESHOLD,
      freeSpins: (user.freeSpins || 0) + 1,
    };
  }

  return null;
}

module.exports = { checkLossRecovery, LOSS_STREAK_THRESHOLD };