const User = require("../../models/auth/user.model");

// Reward table — day index → reward
// After day 7 the cycle repeats from day 1
const REWARD_TABLE = [
  { day: 1, type: "ticket", label: "Free Ticket",  amount: 0  },
  { day: 2, type: "bonus",  label: "₹5 Bonus",     amount: 5  },
  { day: 3, type: "bonus",  label: "₹10 Bonus",    amount: 10 },
  { day: 4, type: "bonus",  label: "₹15 Bonus",    amount: 15 },
  { day: 5, type: "bonus",  label: "₹20 Bonus",    amount: 20 },
  { day: 6, type: "bonus",  label: "₹30 Bonus",    amount: 30 },
  { day: 7, type: "bonus",  label: "₹50 Jackpot",  amount: 50 },
];

function todayStr() {
  const d = new Date();
  return d.toISOString().slice(0, 10); // YYYY-MM-DD
}

function yesterdayStr() {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return d.toISOString().slice(0, 10);
}

/**
 * Get the user's daily reward status (has claimed today? streak info? next reward?)
 */
async function getStatus(email) {
  const user = await User.findOne({ email });
  if (!user) throw new Error("User not found");

  const today = todayStr();
  const claimedToday = user.lastDailyRewardDate === today;
  const streak = user.dailyRewardStreak || 0;

  // Current reward day (1-based index into table)
  const currentDay = claimedToday
    ? ((streak - 1) % REWARD_TABLE.length)   // already claimed — show what they got
    : (streak % REWARD_TABLE.length);         // next to claim

  return {
    claimedToday,
    streak,
    rewardTable: REWARD_TABLE,
    currentDayIndex: currentDay, // 0-based index
    todayReward: REWARD_TABLE[currentDay],
  };
}

/**
 * Claim today's daily reward
 */
async function claim(email) {
  const user = await User.findOne({ email });
  if (!user) throw new Error("User not found");

  const today = todayStr();
  const yesterday = yesterdayStr();

  // Already claimed today
  if (user.lastDailyRewardDate === today) {
    return { success: false, message: "Already claimed today", alreadyClaimed: true };
  }

  // Calculate new streak
  let newStreak;
  if (user.lastDailyRewardDate === yesterday) {
    // Consecutive day — continue streak
    newStreak = (user.dailyRewardStreak || 0) + 1;
  } else {
    // Missed a day or first time — reset streak to 1
    newStreak = 1;
  }

  // Determine reward (0-based index, cycling through table)
  const dayIndex = (newStreak - 1) % REWARD_TABLE.length;
  const reward = REWARD_TABLE[dayIndex];

  // Credit reward
  if (reward.type === "ticket") {
    // Free ticket → grant 1 free spin
    user.freeSpins = (user.freeSpins || 0) + 1;
  } else if (reward.amount > 0) {
    user.balance = (user.balance || 0) + reward.amount;
  }

  user.dailyRewardStreak = newStreak;
  user.lastDailyRewardDate = today;
  await user.save();

  return {
    success: true,
    streak: newStreak,
    reward,
    newBalance: user.balance,
    freeSpins: user.freeSpins || 0,
  };
}

module.exports = { getStatus, claim, REWARD_TABLE };
