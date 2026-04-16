const RouletteEngine             = require("../../game/roulette/roulette.engine");
const RouletteGame               = require("../../models/roulette/rouletteGame.model");
const User                       = require("../../models/auth/user.model");
const { shouldBoost, incrementGamesPlayed } = require("../engagement/earlyBoost");
const { checkAndAward }          = require("../engagement/smallRewards");
const { checkLossRecovery }      = require("../engagement/lossRecovery");
const FEES                       = require("../../config/gameFees");

// ── Per-game field names ──────────────────────────────────────────────────────
const GAME_FIELD = "rouletteGamesPlayed";   // per-game play counter on User doc
const LOSS_FIELD = "rouletteLossStreak";    // consecutive loss counter on User doc

// ── Win rate table by Roulette games played ──────────────────────────────────
// Games 0–3   → 95%  (early boost — great first experience)
// Games 4–10  → 60%
// Games 11–20 → 50%
// Games 21–40 → 38%
// Games 41+   → 20%  (house edge kicks in heavily)
const WIN_RATE_TABLE = [
  { minGames:  0, maxGames:   3, winRate: 0.97 },
  { minGames:  4, maxGames:  10, winRate: 0.60 },
  { minGames: 11, maxGames:  20, winRate: 0.50 },
  { minGames: 21, maxGames:  40, winRate: 0.40 },
  { minGames: 41, maxGames: Infinity, winRate: 0.20 },
];

// After 6 consecutive roulette losses → trigger attraction burst
const ATTRACTION_LOSS_TRIGGER = 6;
// How many extra boosted-win games follow the sudden win
const ATTRACTION_BURST_GAMES  = 2;

function getWinRate(gamesPlayed) {
  for (const tier of WIN_RATE_TABLE) {
    if (gamesPlayed >= tier.minGames && gamesPlayed <= tier.maxGames) {
      return tier.winRate;
    }
  }
  return 0.20;
}

class RouletteService {

  // ── Play a round ─────────────────────────────────────────────
  async playGame(userId, username, bets, useFreeSpins) {
    // Validate all bets
    if (!Array.isArray(bets) || bets.length === 0) {
      throw new Error("At least one bet is required");
    }
    for (const bet of bets) {
      const err = RouletteEngine.validateBet(bet);
      if (err) throw new Error(err);
    }

    const email    = String(userId || "").trim().toLowerCase();
    const userDoc  = await User.findOne({ email });
    if (!userDoc) throw new Error("User not found");

    const totalBet = bets.reduce((sum, b) => sum + b.amount, 0);

    // ── Deduct fee or free spin ───────────────────────────────
    let freeSpinUsed = false;
    if (useFreeSpins && (userDoc.freeSpins || 0) > 0) {
      userDoc.freeSpins -= 1;
      freeSpinUsed = true;
    } else {
      if (userDoc.balance < totalBet) {
        throw new Error(`Insufficient balance. Need ₹${totalBet}, have ₹${userDoc.balance}`);
      }
      userDoc.balance -= totalBet;
    }
    await userDoc.save();

    // ── Read per-game engagement fields ──────────────────────
    const rouletteGamesPlayed = userDoc[GAME_FIELD]             || 0;
    const rouletteLossStreak  = userDoc[LOSS_FIELD]             || 0;
    const currentAttrBurst    = userDoc.rouletteAttractionBurst || 0;

    // ── Decide outcome ────────────────────────────────────────
    let spinResult;
    let attractionTriggered = false;

    // Priority 1: early boost (first 0–3 roulette games → ~95% win)
    const boost = await shouldBoost(email, GAME_FIELD);
    if (boost) {
      spinResult = RouletteEngine.spin(bets, true, 5);
      console.log(`[roulette] 🚀 Early boost for ${email} (games=${rouletteGamesPlayed})`);

    // Priority 2: attraction burst already running
    } else if (currentAttrBurst > 0) {
      spinResult = RouletteEngine.spin(bets, true, 5);
      console.log(`[roulette] ⚡ Attraction burst for ${email} (burst remaining=${currentAttrBurst})`);
      await User.updateOne({ email }, { $inc: { rouletteAttractionBurst: -1 } });

    // Priority 3: trigger attraction burst after N consecutive losses
    } else if (rouletteLossStreak >= ATTRACTION_LOSS_TRIGGER) {
      spinResult = RouletteEngine.spin(bets, true, 5);
      attractionTriggered = true;
      console.log(`[roulette] ⚡ Attraction TRIGGERED for ${email} (lossStreak=${rouletteLossStreak})`);
      await User.updateOne(
        { email },
        { $set: { rouletteAttractionBurst: ATTRACTION_BURST_GAMES, [LOSS_FIELD]: 0 } }
      );

    // Priority 4: normal — apply win rate table
    } else {
      const winRate   = getWinRate(rouletteGamesPlayed);
      const roll      = Math.random();
      const shouldWin = roll < winRate;

      // forceWin=true makes the engine retry spins until player wins something
      spinResult = RouletteEngine.spin(bets, shouldWin, 4);

      console.log(`[roulette] ${email} games=${rouletteGamesPlayed} winRate=${winRate} roll=${roll.toFixed(2)} → ${shouldWin ? "WIN" : "LOSE"}`);
    }

    // Always count this game
    await incrementGamesPlayed(email, GAME_FIELD);

    // ── Calculate payout ──────────────────────────────────────
    const { totalWin, betResults } = RouletteEngine.calculatePayout(bets, spinResult);
    const result = totalWin > 0 ? "WIN" : "LOSE";

    // ── Update loss streak ────────────────────────────────────
    if (!attractionTriggered) {
      if (result === "WIN") {
        await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });
      } else {
        await User.updateOne({ email }, { $inc: { [LOSS_FIELD]: 1 } });
        console.log(`[roulette] ${email} loss streak: ${rouletteLossStreak + 1}`);
      }
    }

    // ── Save game record ──────────────────────────────────────
    const betsWithResults = bets.map((bet, i) => ({ ...bet, ...betResults[i] }));

    const record = await RouletteGame.create({
      userId,
      username:     username || "Anonymous",
      bets:         betsWithResults,
      totalBet,
      spinResult:   spinResult.num,
      resultColor:  spinResult.color,
      resultParity: spinResult.parity,
      resultHalf:   spinResult.half,
      resultDozen:  spinResult.dozen,
      resultColumn: spinResult.column,
      totalWin,
      result,
      freeSpinUsed,
    });

    let newWinCount = null;

    // ── Credit winnings ───────────────────────────────────────
    if (result === "WIN") {
      try {
        const updated = await User.findOneAndUpdate(
          { email },
          { $inc: { wins: 1, balance: totalWin } },
          { new: true }
        );
        newWinCount = updated ? updated.wins : null;
        console.log(`[roulette] ${email} won ₹${totalWin} → wins: ${newWinCount}`);
      } catch (err) {
        console.error("[roulette] failed to credit winnings:", err.message);
      }
    }

    // ── Engagement rewards ────────────────────────────────────
    const reward   = await checkAndAward(email, result === "WIN");
    const recovery = await checkLossRecovery(email, result === "WIN");

    // ── Win type badge ────────────────────────────────────────
    // jackpot = single number hit (19x) | rare | popular | normal
    let winType = "normal";
    const wonSingleNumber = betResults.some(b => b.betType === "number" && b.won);
    if (wonSingleNumber) {
      winType = "jackpot";
    } else {
      const badgeRoll = Math.random();
      if      (badgeRoll < 0.10) winType = "rare";
      else if (badgeRoll < 0.25) winType = "popular";
    }
    if (result === "WIN") await RouletteGame.findByIdAndUpdate(record._id, { winType });

    // ── Popular number stats from recent games ────────────────
    let popularNumber  = null;
    let popularPercent = 0;
    try {
      const recent = await RouletteGame.find()
        .sort({ createdAt: -1 })
        .limit(50)
        .select("spinResult")
        .lean();

      if (recent.length >= 5) {
        const freq = {};
        recent.forEach(g => { freq[g.spinResult] = (freq[g.spinResult] || 0) + 1; });
        const top = Object.entries(freq).sort((a, b) => b[1] - a[1])[0];
        popularNumber  = Number(top[0]);
        popularPercent = Math.round((top[1] / recent.length) * 100);
      } else {
        popularNumber  = Math.floor(Math.random() * 37);
        popularPercent = Math.floor(Math.random() * 20) + 10;
      }
    } catch (_) {
      popularNumber  = Math.floor(Math.random() * 37);
      popularPercent = Math.floor(Math.random() * 20) + 10;
    }

    const updatedUser = await User.findOne({ email });
    const newBalance  = updatedUser ? updatedUser.balance : null;

    return {
      record,
      newWinCount,
      reward,
      recovery,
      newBalance,
      totalWin,
      totalBet,
      netChange: totalWin - totalBet,
      winType,
      freeSpinUsed,
      freeSpins:     updatedUser ? (updatedUser.freeSpins || 0) : 0,
      spinResult:    spinResult.num,
      resultColor:   spinResult.color,
      resultParity:  spinResult.parity,
      resultHalf:    spinResult.half,
      resultDozen:   spinResult.dozen,
      resultColumn:  spinResult.column,
      betResults,
      popularNumber,
      popularPercent,
    };
  }

  // ── User history ──────────────────────────────────────────────
  async getUserHistory(userId, limit) {
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    return RouletteGame.find({ userId })
      .sort({ createdAt: -1 })
      .limit(safeLimit);
  }

  // ── User stats ────────────────────────────────────────────────
  async getUserStats(userId) {
    const games  = await RouletteGame.find({ userId });
    const total  = games.length;
    const wins   = games.filter(g => g.result === "WIN").length;
    const losses = total - wins;
    const totalWon  = games.reduce((s, g) => s + (g.totalWin  || 0), 0);
    const totalBet  = games.reduce((s, g) => s + (g.totalBet  || 0), 0);
    return {
      total,
      wins,
      losses,
      winRate:  total > 0 ? Math.round((wins / total) * 100) : 0,
      totalWon,
      totalBet,
      netProfit: totalWon - totalBet,
    };
  }
}

module.exports = new RouletteService();