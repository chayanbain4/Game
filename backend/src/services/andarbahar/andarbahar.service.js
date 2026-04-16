const AndarBaharEngine = require("../../game/andarbahar/andarbahar.engine");
const AndarBaharGame   = require("../../models/andarbahar/andarbaharGame.model");
const User             = require("../../models/auth/user.model");
const { shouldBoost, incrementGamesPlayed } = require("../engagement/earlyBoost");
const { checkAndAward }     = require("../engagement/smallRewards");
const { checkLossRecovery } = require("../engagement/lossRecovery");
const FEES = require("../../config/gameFees");

// ── Per-game field names ──────────────────────────────────────────────────────
const GAME_FIELD      = "andarbaharGamesPlayed";   // per-game play counter
const LOSS_FIELD      = "andarbaharLossStreak";    // per-game loss streak

// ── Win rate table by Andar Bahar games played ───────────────────────────────
// Games 0–3   → 97%  (early boost — first time AB player gets a great experience)
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

// After this many consecutive AB losses → sudden forced win (attraction burst)
const ATTRACTION_LOSS_TRIGGER = 7;
// How many extra boosted-win games follow the sudden win
const ATTRACTION_BURST_GAMES  = 2;

function getWinRate(gamesPlayed) {
  for (const tier of WIN_RATE_TABLE) {
    if (gamesPlayed >= tier.minGames && gamesPlayed <= tier.maxGames) {
      return tier.winRate;
    }
  }
  return 0.20; // fallback: 41+ tier
}

class AndarBaharService {

  // ── Play a round ─────────────────────────────────────────────
  async playGame(userId, username, playerChoice, useFreeSpins) {
    const choice = (playerChoice || "").toUpperCase().trim();
    if (choice !== "ANDAR" && choice !== "BAHAR") {
      throw new Error("Choice must be ANDAR or BAHAR");
    }

    const email = String(userId || "").trim().toLowerCase();

    // Fetch user — need balance, per-game counter, loss streak, burst counter
    const userDoc = await User.findOne({ email });
    if (!userDoc) throw new Error("User not found");

    // Deduct entry fee or use free spin
    const fee = FEES.ANDARBAHAR;
    let freeSpinUsed = false;
    if (useFreeSpins && (userDoc.freeSpins || 0) > 0) {
      userDoc.freeSpins -= 1;
      freeSpinUsed = true;
    } else {
      if (userDoc.balance < fee) throw new Error(`Insufficient balance. Need ₹${fee}, have ₹${userDoc.balance}`);
      userDoc.balance -= fee;
    }
    await userDoc.save();

    // Read per-game fields
    const abGamesPlayed    = userDoc[GAME_FIELD]         || 0;
    const abLossStreak     = userDoc[LOSS_FIELD]         || 0;
    const currentAttrBurst = userDoc.abAttractionBurst   || 0;

    // ── Decide outcome ────────────────────────────────────────
    let game;
    let attractionTriggered = false;

    // Priority 1: early boost — first 0–3 Andar Bahar games → ~97% win
    const boost = await shouldBoost(email, GAME_FIELD);
    if (boost) {
      game = AndarBaharEngine.play(choice, 5);
      console.log(`[andarbahar] 🚀 Early boost for ${email} (abGames=${abGamesPlayed})`);

    // Priority 2: attraction burst already running
    } else if (currentAttrBurst > 0) {
      game = AndarBaharEngine.play(choice, 5);
      console.log(`[andarbahar] ⚡ Attraction burst for ${email} (burst remaining=${currentAttrBurst})`);
      await User.updateOne({ email }, { $inc: { abAttractionBurst: -1 } });

    // Priority 3: trigger attraction burst after 7 consecutive AB losses
    } else if (abLossStreak >= ATTRACTION_LOSS_TRIGGER) {
      game = AndarBaharEngine.play(choice, 5);
      attractionTriggered = true;
      console.log(`[andarbahar] ⚡ Attraction TRIGGERED for ${email} (abLossStreak=${abLossStreak}) — sudden win + burst`);
      await User.updateOne(
        { email },
        { $set: { abAttractionBurst: ATTRACTION_BURST_GAMES, [LOSS_FIELD]: 0 } }
      );

    // Priority 4: normal — apply win rate table based on AB games played
    } else {
      const winRate   = getWinRate(abGamesPlayed);
      const roll      = Math.random();
      const shouldWin = roll < winRate;

      if (shouldWin) {
        game = AndarBaharEngine.play(choice, 3);
      } else {
        const opposite = choice === "ANDAR" ? "BAHAR" : "ANDAR";
        game = AndarBaharEngine.play(opposite, 3);
      }

      console.log(`[andarbahar] ${email} abGames=${abGamesPlayed} winRate=${winRate} roll=${roll.toFixed(2)} → ${shouldWin ? "WIN" : "LOSE"}`);
    }

    // Always count this AB game
    await incrementGamesPlayed(email, GAME_FIELD);

    // Determine result
    const result = choice === game.winningSide ? "WIN" : "LOSE";

    // ── Update per-game loss streak ───────────────────────────
    if (!attractionTriggered) {
      if (result === "WIN") {
        await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });
      } else {
        await User.updateOne({ email }, { $inc: { [LOSS_FIELD]: 1 } });
        console.log(`[andarbahar] ${email} AB loss streak: ${abLossStreak + 1}`);
      }
    }

    // Save game record to DB
    const record = await AndarBaharGame.create({
      userId,
      username:     username || "Anonymous",
      playerChoice: choice,
      jokerCard:    game.joker,
      andarCards:   game.andarCards,
      baharCards:   game.baharCards,
      matchingCard: game.matchingCard,
      winningSide:  game.winningSide,
      result,
      totalDealt:   game.totalDealt,
    });

    let newWinCount = null;
    let winAmount   = 0;

    // Credit prize if won
    if (result === "WIN") {
      winAmount = FEES.WIN_REWARDS.ANDARBAHAR;
      try {
        const updated = await User.findOneAndUpdate(
          { email },
          { $inc: { wins: 1, balance: winAmount } },
          { new: true }
        );
        newWinCount = updated ? updated.wins : null;
        console.log(`[andarbahar] ${email} wins → ${newWinCount}, credited ₹${winAmount}`);
      } catch (err) {
        console.error("[andarbahar] failed to update wins:", err.message);
      }
    }

    // Small frequent reward check
    const reward = await checkAndAward(email, result === "WIN");

    // Global loss recovery (free ticket after 5 global losses)
    const recovery = await checkLossRecovery(email, result === "WIN");

    // Cosmetic winType badge
    let winType = "normal";
    const badgeRoll = Math.random();
    if (badgeRoll < 0.15)      winType = "rare";
    else if (badgeRoll < 0.30) winType = "popular";

    // Popular choice stats from recent games
    let popularChoice  = "ANDAR";
    let popularPercent = 50;
    try {
      const recent = await AndarBaharGame.find()
        .sort({ createdAt: -1 })
        .limit(50)
        .select("playerChoice")
        .lean();
      if (recent.length >= 5) {
        const andarCount = recent.filter(g => g.playerChoice === "ANDAR").length;
        const pct        = Math.round((andarCount / recent.length) * 100);
        popularChoice  = pct >= 50 ? "ANDAR" : "BAHAR";
        popularPercent = pct >= 50 ? pct : 100 - pct;
      } else {
        popularChoice  = Math.random() < 0.5 ? "ANDAR" : "BAHAR";
        popularPercent = Math.floor(Math.random() * 21) + 55;
      }
    } catch (_) {
      popularChoice  = Math.random() < 0.5 ? "ANDAR" : "BAHAR";
      popularPercent = Math.floor(Math.random() * 21) + 55;
    }

    const updatedUser = await User.findOne({ email });
    const newBalance  = updatedUser ? updatedUser.balance : null;

    return {
      record,
      newWinCount,
      reward,
      recovery,
      newBalance,
      winAmount,
      winType,
      freeSpinUsed,
      freeSpins: updatedUser ? (updatedUser.freeSpins || 0) : 0,
      popularChoice,
      popularPercent,
    };
  }

  // ── User history ──────────────────────────────────────────────
  async getUserHistory(userId, limit) {
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    return AndarBaharGame.find({ userId })
      .sort({ createdAt: -1 })
      .limit(safeLimit);
  }

  // ── User stats ────────────────────────────────────────────────
  async getUserStats(userId) {
    const games  = await AndarBaharGame.find({ userId });
    const total  = games.length;
    const wins   = games.filter(g => g.result === "WIN").length;
    const losses = total - wins;
    return {
      total,
      wins,
      losses,
      winRate: total > 0 ? Math.round((wins / total) * 100) : 0,
    };
  }
}

module.exports = new AndarBaharService();