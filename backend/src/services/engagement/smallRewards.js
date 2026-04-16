const User = require("../../models/auth/user.model");

// ── Small Frequent Rewards ────────────────────────────────────
// After every TRIGGER_THRESHOLD games without winning,
// give the user a small consolation reward to keep them engaged.

const TRIGGER_THRESHOLD = 3; // games between rewards

const REWARD_POOL = [
  { type: "cash", amount: 2,  label: "₹2",  message: "Here's ₹2 to keep playing!" },
  { type: "cash", amount: 2,  label: "₹2",  message: "A little something for you!" },
  { type: "cash", amount: 5,  label: "₹5",  message: "You just earned ₹5!" },
  { type: "cash", amount: 5,  label: "₹5",  message: "₹5 bonus — keep going!" },
  { type: "cash", amount: 10, label: "₹10", message: "Nice! ₹10 reward for you!" },
  { type: "ticket", amount: 0, label: "Free Ticket", message: "You won a free ticket!" },
];

/**
 * Call after every game. Returns a reward object if one is earned, or null.
 * If the user WON this game, pass didWin=true to reset the counter.
 */
async function checkAndAward(email, didWin = false) {
  if (!email) {
    console.log('[smallReward] no email, skipping');
    return null;
  }
  const normalizedEmail = String(email).trim().toLowerCase();
  console.log(`[smallReward] email=${normalizedEmail}, didWin=${didWin}`);

  if (didWin) {
    // Reset counter on any win
    await User.updateOne(
      { email: normalizedEmail },
      { $set: { gamesSinceLastReward: 0 } }
    );
    console.log('[smallReward] win — counter reset');
    return null;
  }

  // Increment counter
  const user = await User.findOneAndUpdate(
    { email: normalizedEmail },
    { $inc: { gamesSinceLastReward: 1 } },
    { new: true, select: "gamesSinceLastReward balance" }
  );

  if (!user) {
    console.log('[smallReward] user not found in DB');
    return null;
  }

  console.log(`[smallReward] counter=${user.gamesSinceLastReward}, threshold=${TRIGGER_THRESHOLD}`);

  if (user.gamesSinceLastReward >= TRIGGER_THRESHOLD) {
    // Pick a random reward
    const reward = REWARD_POOL[Math.floor(Math.random() * REWARD_POOL.length)];

    // Reset counter and credit balance/freeSpins
    const update = { $set: { gamesSinceLastReward: 0 } };
    if (reward.type === "cash" && reward.amount > 0) {
      update.$inc = { balance: reward.amount };
    } else if (reward.type === "ticket") {
      update.$inc = { freeSpins: 1 };
    }
    const updated = await User.findOneAndUpdate(
      { email: normalizedEmail },
      update,
      { new: true, select: "balance freeSpins" }
    );

    console.log(`[smallReward] 🎁 REWARD GIVEN: ${reward.label} to ${normalizedEmail}, newBalance=${updated?.balance}, freeSpins=${updated?.freeSpins}`);

    return {
      type: reward.type,
      amount: reward.amount,
      label: reward.label,
      message: reward.message,
      newBalance: updated ? updated.balance : user.balance,
      freeSpins: updated ? (updated.freeSpins || 0) : 0,
    };
  }

  console.log('[smallReward] not yet at threshold, no reward');
  return null;
}

module.exports = { checkAndAward, TRIGGER_THRESHOLD };
