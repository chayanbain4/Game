const NumberResult = require("../../models/number/numberGame.model");
const User = require("../../models/auth/user.model");
const { checkAndAward } = require("../../services/engagement/smallRewards");
const { checkLossRecovery } = require("../../services/engagement/lossRecovery");

// ── Per-game field names ──────────────────────────────────────────────────────
const GAME_FIELD = "numberGamesPlayed";
const LOSS_FIELD = "numberLossStreak";

// ── Fixed bet amount ──────────────────────────────────────────────────────────
const BET_AMOUNT = 3;

// ── Win rate table ────────────────────────────────────────────────────────────
const WIN_RATE_TABLE = [
  { minGames: 0, maxGames: 3, winRate: 0.97 },
  { minGames: 4, maxGames: 10, winRate: 0.60 },
  { minGames: 11, maxGames: 20, winRate: 0.50 },
  { minGames: 21, maxGames: 40, winRate: 0.40 },
  { minGames: 41, maxGames: Infinity, winRate: 0.20 },
];

// After 7 consecutive losses → forced win
const ATTRACTION_LOSS_TRIGGER = 7;

function getWinRate(gamesPlayed) {
  for (const tier of WIN_RATE_TABLE) {
    if (gamesPlayed >= tier.minGames && gamesPlayed <= tier.maxGames) {
      return tier.winRate;
    }
  }
  return 0.20;
}

exports.play = async (req, res) => {
  try {
    const {
      email,
      number,
      betCount = 1,
      useFreeSpins = false,
    } = req.body;

    const userNumber = Number(number);
    const parsedBetCount = Number(betCount);

    // 1) Validate input
    if (!Number.isInteger(userNumber) || userNumber < 0 || userNumber > 9) {
      return res.status(400).json({
        success: false,
        message: "Invalid number. Must be 0–9.",
      });
    }

    if (!Number.isInteger(parsedBetCount) || parsedBetCount < 1) {
      return res.status(400).json({
        success: false,
        message: "Invalid betCount. Must be a positive integer.",
      });
    }

    const userStr = String(email || req.user?.email || "")
      .trim()
      .toLowerCase();

    const user = await User.findOne({ email: userStr });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // 2) Calculate free-spin usage + paid deduction
    const availableFreeSpins = user.freeSpins || 0;
    const freeSpinBetCount = useFreeSpins
      ? Math.min(availableFreeSpins, parsedBetCount)
      : 0;

    const paidBetCount = parsedBetCount - freeSpinBetCount;
    const totalDeduct = paidBetCount * BET_AMOUNT;
    const totalStakeAmount = parsedBetCount * BET_AMOUNT;

    if (user.balance < totalDeduct) {
      return res.status(400).json({
        success: false,
        message: `Insufficient balance. Need ₹${totalDeduct}, have ₹${user.balance}`,
      });
    }

    // 3) Deduct balance / free spins once for the full round
    if (freeSpinBetCount > 0) {
      user.freeSpins -= freeSpinBetCount;
    }
    if (totalDeduct > 0) {
      user.balance -= totalDeduct;
    }

    // 4) Read stats for one round decision
    const gamesPlayed = user[GAME_FIELD] || 0;
    const lossStreak = user[LOSS_FIELD] || 0;
    const winRate = getWinRate(gamesPlayed);

    // 5) Determine single round win/lose
    let isWin = false;

    if (lossStreak >= ATTRACTION_LOSS_TRIGGER) {
      isWin = true;
      user[LOSS_FIELD] = 0;
      console.log(
        `[number] ⚡ Attraction burst for ${userStr} (lossStreak=${lossStreak}) — forced win`
      );
    } else {
      const roll = Math.random();
      isWin = roll < winRate;
      console.log(
        `[number] winRate check: ${userStr} games=${gamesPlayed} rate=${winRate} roll=${roll.toFixed(
          3
        )} → ${isWin ? "WIN" : "LOSE"}`
      );
    }

    // 6) Generate one winning number for the whole round
    let winningNumber;
    if (isWin) {
      winningNumber = userNumber;
    } else {
      do {
        winningNumber = Math.floor(Math.random() * 10);
      } while (winningNumber === userNumber);
    }

    // 7) Calculate payout for the full round
    // Example:
    // 1 bet  => ₹3 stake => win ₹6 total payout
    // 2 bets => ₹6 stake => win ₹12 total payout
    // 11 bets => ₹33 stake => win ₹66 total payout
    const totalPayout = isWin ? totalStakeAmount * 2 : 0;

    // 8) Update user stats once per round
    user[GAME_FIELD] = gamesPlayed + 1;
    user.totalGamesPlayed = (user.totalGamesPlayed || 0) + 1;

    if (isWin) {
      user.balance += totalPayout;
      user.wins = (user.wins || 0) + 1;
      user[LOSS_FIELD] = 0;
    } else {
      if (lossStreak < ATTRACTION_LOSS_TRIGGER) {
        user[LOSS_FIELD] = lossStreak + 1;
      }
    }

    await user.save();

    // 9) Save round history
    await NumberResult.create({
      round: Date.now(),
      result: winningNumber,
      totalPlayers: 1,
      winType: "normal",
    });

    // 10) Rewards / recovery
    let smallReward = null;
    let lossRecovery = null;

    try {
      smallReward = await checkAndAward(userStr, isWin);
    } catch (e) {
      console.log("[number] smallReward error:", e.message);
    }

    try {
      lossRecovery = await checkLossRecovery(userStr, isWin);
    } catch (e) {
      console.log("[number] lossRecovery error:", e.message);
    }

    // 11) Re-read in case reward services changed wallet/free spins
    let finalBalance = user.balance;
    let finalFreeSpins = user.freeSpins || 0;

    if (smallReward || lossRecovery) {
      const refreshed = await User.findOne({ email: userStr })
        .select("balance freeSpins wins")
        .lean();

      if (refreshed) {
        finalBalance = refreshed.balance;
        finalFreeSpins = refreshed.freeSpins || 0;
      }
    }

    console.log(
      `[number] ${userStr} → ${isWin ? "WIN" : "LOSE"} | chosen=${userNumber} | result=${winningNumber} | betCount=${parsedBetCount} | deducted=₹${totalDeduct} | payout=₹${totalPayout} | balance=₹${finalBalance}`
    );

    // 12) Send one consistent response for one round
    return res.json({
      success: true,
      data: {
        result: winningNumber,
        isWin,
        selectedNumber: userNumber,
        betCount: parsedBetCount,
        freeSpinBetCount,
        paidBetCount,
        betAmount: BET_AMOUNT,
        totalStakeAmount,
        deductedAmount: totalDeduct,
        winAmount: totalPayout, // full payout sent to frontend
        netProfit: isWin ? totalPayout - totalDeduct : -totalDeduct,
        newBalance: finalBalance,
        freeSpins: finalFreeSpins,
        newWinCount: user.wins,
        smallReward: smallReward || null,
        lossRecovery: lossRecovery || null,
      },
    });
  } catch (err) {
    console.error("[number] Play error:", err);
    return res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};