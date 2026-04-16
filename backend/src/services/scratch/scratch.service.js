const ScratchEngine = require("../../game/scratch/scratch.engine");
const ScratchResult = require("../../models/scratch/scratchResult.model");
const User = require("../../models/auth/user.model");
const { shouldBoost, incrementGamesPlayed } = require("../engagement/earlyBoost");
const { checkAndAward }     = require("../engagement/smallRewards");
const { checkLossRecovery } = require("../engagement/lossRecovery");
const FEES = require("../../config/gameFees");

// ── Per-game field names ──────────────────────────────────────────────────────
const GAME_FIELD = "scratchGamesPlayed";  // per-game play counter
const LOSS_FIELD = "scratchLossStreak";   // per-game loss streak

// ── Win rate table by Scratch games played ───────────────────────────────────
// Games 0–3   → 97%  (early boost — first-time Scratch player gets great wins)
// Games 4–10  → 60%
// Games 11–20 → 50%
// Games 21–40 → 40%
// Games 41+   → 20%  (old players lose much more often)
const WIN_RATE_TABLE = [
  { minGames:  0, maxGames:   3, winRate: 0.97 },
  { minGames:  4, maxGames:  10, winRate: 0.60 },
  { minGames: 11, maxGames:  20, winRate: 0.50 },
  { minGames: 21, maxGames:  40, winRate: 0.40 },
  { minGames: 41, maxGames: Infinity, winRate: 0.20 },
];

// After 7 consecutive Scratch losses → sudden forced win
const ATTRACTION_LOSS_TRIGGER = 7;

function getWinRate(gamesPlayed) {
  for (const tier of WIN_RATE_TABLE) {
    if (gamesPlayed >= tier.minGames && gamesPlayed <= tier.maxGames) {
      return tier.winRate;
    }
  }
  return 0.20;
}

class ScratchService {

  // ── Play a scratch card and save result ──────────────────────
  // Added multiplier parameter (defaults to 1 if not provided)
  async playScratchCard(userId, username, useFreeSpins, multiplier = 1) {
    const email = String(userId || "").trim().toLowerCase();

    // Fetch user
    const user = await User.findOne({ email });
    if (!user) throw new Error("User not found");

    // Deduct entry fee or use free spin (Fee is multiplied by the chosen multiplier)
    const fee = FEES.SCRATCH * multiplier; 
    let freeSpinUsed = false;
    
    if (useFreeSpins && (user.freeSpins || 0) > 0) {
      user.freeSpins -= 1;
      freeSpinUsed = true;
    } else {
      if (user.balance < fee) throw new Error(`Insufficient balance. Need ₹${fee}, have ₹${user.balance}`);
      user.balance -= fee;
    }
    await user.save();

    // Read per-game fields
    const scratchGamesPlayed = user[GAME_FIELD] || 0;
    const scratchLossStreak  = user[LOSS_FIELD] || 0;
    const winRate            = getWinRate(scratchGamesPlayed);
    const roll               = Math.random();

    // ── Decide outcome ────────────────────────────────────────
    let outcome;
    let attractionTriggered = false;

    // Priority 1: early boost — first 0–3 Scratch games → ~97% win
    const boost = await shouldBoost(email, GAME_FIELD);
    if (boost) {
      console.log(`[scratch] 🚀 Early boost for ${email} (scratchGames=${scratchGamesPlayed})`);
      for (let i = 0; i < 10; i++) {
        outcome = ScratchEngine.play();
        if (outcome.result === "WIN") break;
      }

    // Priority 2: attraction burst — 7 consecutive Scratch losses → sudden win
    } else if (scratchLossStreak >= ATTRACTION_LOSS_TRIGGER) {
      console.log(`[scratch] ⚡ Attraction burst for ${email} (scratchLossStreak=${scratchLossStreak}) — forced WIN`);
      attractionTriggered = true;
      for (let i = 0; i < 20; i++) {
        outcome = ScratchEngine.play();
        if (outcome.result === "WIN") break;
      }
      await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });

    // Priority 3: win rate table
    } else {
      const shouldWin = roll < winRate;
      console.log(`[scratch] ${email} scratchGames=${scratchGamesPlayed} winRate=${winRate} roll=${roll.toFixed(3)} → ${shouldWin ? "WIN" : "LOSE"}`);

      if (shouldWin) {
        for (let i = 0; i < 10; i++) {
          outcome = ScratchEngine.play();
          if (outcome.result === "WIN") break;
        }
      } else {
        outcome = ScratchEngine.play();
      }
    }

    // Always count this Scratch game
    await incrementGamesPlayed(email, GAME_FIELD);

    // ── Near-miss: force exactly 2 diamonds on LOSE cards ────
    if (outcome.result === "LOSE") {
      const dCount = outcome.cells.filter(c => c === "diamond").length;
      if (dCount < 2) {
        let needed = 2 - dCount;
        for (let i = 0; i < outcome.cells.length && needed > 0; i++) {
          if (outcome.cells[i] !== "diamond") {
            outcome.cells[i] = "diamond";
            needed--;
          }
        }
        outcome.matchCount = 2;
      }
    }

    // ── Update per-game loss streak ───────────────────────────
    if (!attractionTriggered) {
      if (outcome.result === "WIN") {
        await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });
      } else {
        await User.updateOne({ email }, { $inc: { [LOSS_FIELD]: 1 } });
        console.log(`[scratch] ${email} scratch loss streak: ${scratchLossStreak + 1}`);
      }
    }

    // Save result record
    const record = await ScratchResult.create({
      userId,
      username:   username || "Anonymous",
      cells:      outcome.cells,
      result:     outcome.result,
      symbol:     outcome.symbol,
      matchCount: outcome.matchCount,
      multiplier: outcome.multiplier, // Note: This refers to the symbol multiplier from the engine
    });

    let newWinCount = null;
    let winAmount   = 0;

    // Credit prize if won
    if (outcome.result === "WIN") {
      // Multiply the standard reward by the chosen multiplier
      winAmount = FEES.WIN_REWARDS.SCRATCH * multiplier; 
      try {
        const updated = await User.findOneAndUpdate(
          { email },
          { $inc: { wins: 1, balance: winAmount } },
          { new: true }
        );
        newWinCount = updated ? updated.wins : null;
        console.log(`[scratch] ${email} wins → ${newWinCount}, credited ₹${winAmount}`);
      } catch (err) {
        console.error("[scratch] failed to update wins:", err.message);
      }
    }

    const reward   = await checkAndAward(email, outcome.result === "WIN");
    const recovery = await checkLossRecovery(email, outcome.result === "WIN");

    const updatedUser = await User.findOne({ email });
    const newBalance  = updatedUser ? updatedUser.balance : null;

    return {
      record,
      newWinCount,
      reward,
      recovery,
      newBalance,
      winAmount,
      freeSpinUsed,
      freeSpins: updatedUser ? (updatedUser.freeSpins || 0) : 0,
      attractionTriggered,
    };
  }

  // ── Get recent scratch results ────────────────────────────────
  async getHistory(limit) {
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    return ScratchResult.find().sort({ createdAt: -1 }).limit(safeLimit);
  }

  // ── Get history for a specific user ──────────────────────────
  async getUserHistory(userId, limit) {
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    return ScratchResult.find({ userId }).sort({ createdAt: -1 }).limit(safeLimit);
  }
}

module.exports = new ScratchService();