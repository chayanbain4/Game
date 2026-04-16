const LotteryEngine = require("../../game/lottery/lottery.engine");
const LotteryDraw   = require("../../models/lottery/lotteryDraw.model");
const LotteryTicket = require("../../models/lottery/lotteryTicket.model");
const User          = require("../../models/auth/user.model");
const { shouldBoost, incrementGamesPlayed } = require("../engagement/earlyBoost");
const { checkAndAward }     = require("../engagement/smallRewards");
const { checkLossRecovery } = require("../engagement/lossRecovery");
const { getLuckyNumbers }   = require("../../utils/luckyNumbers");
const FEES = require("../../config/gameFees");

// ── Per-game field names ──────────────────────────────────────────────────────
const GAME_FIELD = "lotteryGamesPlayed";  // per-game play counter
const LOSS_FIELD = "lotteryLossStreak";   // per-game loss streak

// ── Win rate table by Lottery games played ───────────────────────────────────
const WIN_RATE_TABLE = [
  { minGames:  0, maxGames:   3, winRate: 0.97 },
  { minGames:  4, maxGames:  10, winRate: 0.60 },
  { minGames: 11, maxGames:  20, winRate: 0.50 },
  { minGames: 21, maxGames:  40, winRate: 0.40 },
  { minGames: 41, maxGames: Infinity, winRate: 0.20 },
];

// After 7 consecutive Lottery losses → sudden forced win
const ATTRACTION_LOSS_TRIGGER = 7;

function getWinRate(gamesPlayed) {
  for (const tier of WIN_RATE_TABLE) {
    if (gamesPlayed >= tier.minGames && gamesPlayed <= tier.maxGames) {
      return tier.winRate;
    }
  }
  return 0.20;
}

class LotteryService {

  // ── Buy a ticket ─────────────────────────────────────────────
  async buyTicket(userId, username, numbers, drawNumber, useFreeSpins, multiplier = 1) {
    let chosenNumbers = numbers;
    let isQuickPick   = false;

    if (!chosenNumbers || chosenNumbers.length === 0) {
      chosenNumbers = LotteryEngine.quickPick();
      isQuickPick   = true;
    }

    const validation = LotteryEngine.validateNumbers(chosenNumbers);
    if (!validation.valid) throw new Error(validation.reason);

    // Validate Multiplier (1x, 2x, 5x, 10x)
    const allowedMultipliers = [1, 2, 5, 10];
    if (!allowedMultipliers.includes(multiplier)) {
      throw new Error("Invalid bet multiplier. Allowed: 1x, 2x, 5x, 10x");
    }

    // Fee calculation: Base fee * chosen amount * multiplier
    const fee = (FEES.LOTTERY * chosenNumbers.length) * multiplier;

    const email = String(userId || "").trim().toLowerCase();
    const userDoc = await User.findOne({ email });
    if (!userDoc) throw new Error("User not found");

    let freeSpinUsed = false;
    if (useFreeSpins && (userDoc.freeSpins || 0) > 0) {
      userDoc.freeSpins -= 1;
      freeSpinUsed = true;
      multiplier = 1;
    } else {
      if (userDoc.balance < fee) throw new Error(`Insufficient balance. Need ₹${fee}, have ₹${userDoc.balance}`);
      userDoc.balance -= fee;
    }
    await userDoc.save();

    // ── AUTO-START DRAW if no active OPEN draw exists ─────────────────────────
    // Lazy require avoids circular dependency (draw.manager → lottery.service)
    const drawManager = require("../../game/lottery/draw.manager");

    let activeDrawNumber = drawNumber || null;
    let draw = null;

    // 1. If caller supplied a drawNumber, try to find that specific OPEN draw
    if (activeDrawNumber) {
      draw = await LotteryDraw.findOne({ drawNumber: activeDrawNumber, status: "OPEN" });
    }

    // 2. No open draw found — check if one is already running in draw manager
    if (!draw) {
      const remaining = drawManager.getRemainingTime();
      if (remaining > 0) {
        activeDrawNumber = drawManager.getCurrentDrawNumber();
        draw = await LotteryDraw.findOne({ drawNumber: activeDrawNumber, status: "OPEN" });
        console.log(`[lottery] Joining already-running draw #${activeDrawNumber} (${remaining}s left)`);
      }
    }

    // 3. Still no open draw — auto-trigger a brand new one
    if (!draw) {
      console.log(`[lottery] No open draw found — auto-starting a new draw for user ${email}`);
      const result = await drawManager.triggerManualDraw();
      if (!result.success) throw new Error(`Could not auto-start draw: ${result.message}`);
      activeDrawNumber = result.drawNumber;
      draw = await LotteryDraw.findOne({ drawNumber: activeDrawNumber });
      console.log(`[lottery] Auto-started draw #${activeDrawNumber}`);
    }

    if (!draw)                  throw new Error("Draw not found after auto-start");
    if (draw.status !== "OPEN") throw new Error("This draw is no longer accepting tickets");
    // ─────────────────────────────────────────────────────────────────────────

    const ticket = await LotteryTicket.create({
      userId,
      username: username || "Anonymous",
      drawNumber: activeDrawNumber,
      numbers: chosenNumbers.sort((a, b) => a - b),
      isQuickPick,
      multiplier,
    });

    await LotteryDraw.updateOne({ drawNumber: activeDrawNumber }, { $inc: { totalTickets: 1 } });

    const reward = await checkAndAward(email, false);

    const updatedUser = await User.findOne({ email });
    const newBalance  = updatedUser ? updatedUser.balance : null;

    return {
      ticket,
      reward,
      newBalance,
      freeSpinUsed,
      freeSpins: updatedUser ? (updatedUser.freeSpins || 0) : 0,
    };
  }

  // ── Get the current open draw ─────────────────────────────────
  async getCurrentDraw() {
    // Return the absolute latest draw (whether OPEN or DRAWN)
    return LotteryDraw.findOne().sort({ drawNumber: -1 });
  }

  async getDraw(drawNumber) {
    return LotteryDraw.findOne({ drawNumber });
  }

  async getUserTickets(userId, drawNumber) {
    return LotteryTicket.find({ userId, drawNumber }).sort({ createdAt: -1 });
  }

  async getUserHistory(userId, limit) {
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    return LotteryTicket.find({ userId }).sort({ createdAt: -1 }).limit(safeLimit);
  }

  async getRecentDraws(limit) {
    const safeLimit = Math.min(Math.max(limit || 10, 1), 50);
    return LotteryDraw.find({ status: "DRAWN" }).sort({ drawNumber: -1 }).limit(safeLimit);
  }

  // ── Execute a draw: generate winning numbers & evaluate ───────
  async executeDraw(drawNumber) {
    const draw = await LotteryDraw.findOne({ drawNumber });
    if (!draw)                   throw new Error("Draw not found");
    if (draw.status === "DRAWN") throw new Error("Draw already completed");

    const winningNumbers = LotteryEngine.drawWinningNumbers();
    const tickets        = await LotteryTicket.find({ drawNumber });

    let totalWinners = 0;

    for (const ticket of tickets) {
      const result = LotteryEngine.checkTicket(ticket.numbers, winningNumbers);
      const email  = String(ticket.userId || "").trim().toLowerCase();

      const userDoc = await User.findOne({ email })
        .select(`${GAME_FIELD} ${LOSS_FIELD}`)
        .lean();

      const lotteryGamesPlayed = userDoc ? (userDoc[GAME_FIELD] || 0) : 0;
      const lotteryLossStreak  = userDoc ? (userDoc[LOSS_FIELD] || 0) : 0;
      const winRate            = getWinRate(lotteryGamesPlayed);
      const roll               = Math.random();

      // ── Priority 1: early boost ────
      const earlyUser = await shouldBoost(ticket.userId, GAME_FIELD);
      if (earlyUser && result.result === "LOSE") {
        result.matchedNumbers = winningNumbers.slice(0, 2);
        result.matchCount     = 2;
        result.result         = "WIN";
        result.tier           = "TIER_1";
        result.tierLabel      = "Tier 1 — 2 numbers matched";
        console.log(`[lottery] 🚀 Early boost for ${email} (lotteryGames=${lotteryGamesPlayed}) — forced TIER_1`);

      // ── Priority 2: attraction burst ──
      } else if (lotteryLossStreak >= ATTRACTION_LOSS_TRIGGER && result.result === "LOSE") {
        result.matchedNumbers = winningNumbers.slice(0, 2);
        result.matchCount     = 2;
        result.result         = "WIN";
        result.tier           = "TIER_1";
        result.tierLabel      = "Tier 1 — 2 numbers matched";
        console.log(`[lottery] ⚡ Attraction burst for ${email} (lossStreak=${lotteryLossStreak}) — forced TIER_1`);
        await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });

      // ── Priority 3: win rate table ─────────────────────────────
      } else if (!earlyUser) {
        const shouldWin = roll < winRate;
        console.log(`[lottery] ${email} lotteryGames=${lotteryGamesPlayed} winRate=${winRate} roll=${roll.toFixed(3)} → ${shouldWin ? "WIN-ELIGIBLE" : "FORCE-LOSE"}`);

        if (shouldWin && result.result === "LOSE") {
          result.matchedNumbers = winningNumbers.slice(0, 2);
          result.matchCount     = 2;
          result.result         = "WIN";
          result.tier           = "TIER_1";
          result.tierLabel      = "Tier 1 — 2 numbers matched";
          console.log(`[lottery] ✅ Win-rate boost for ${email} — forced TIER_1`);
        }
      }

      await incrementGamesPlayed(ticket.userId, GAME_FIELD);

      if (lotteryLossStreak < ATTRACTION_LOSS_TRIGGER) {
        if (result.result === "WIN") {
          await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });
        } else {
          await User.updateOne({ email }, { $inc: { [LOSS_FIELD]: 1 } });
          console.log(`[lottery] ${email} lottery loss streak: ${lotteryLossStreak + 1}`);
        }
      }

      ticket.matchedNumbers = result.matchedNumbers;
      ticket.matchCount     = result.matchCount;
      ticket.result         = result.result;
      ticket.tier           = result.tier;
      ticket.tierLabel      = result.tierLabel;
      await ticket.save();

      if (result.result === "WIN") {
        totalWinners++;

        let basePrizeAmount = (FEES.WIN_REWARDS.LOTTERY[result.tier]) || 0;
        let prizeAmount = basePrizeAmount * (ticket.multiplier || 1);

        try {
          const lucky      = getLuckyNumbers(ticket.userId);
          const luckyMatch = result.matchedNumbers.some(n => lucky.includes(n));
          if (luckyMatch) {
            const bonus = Math.round(prizeAmount * 0.5);
            prizeAmount += bonus;
            console.log(`[lottery] ${ticket.userId} lucky bonus +₹${bonus}`);
          }
        } catch (_) {}

        try {
          if (email) {
            await User.findOneAndUpdate(
              { email },
              { $inc: { wins: 1, balance: prizeAmount } }
            );
            console.log(`[lottery] ${email} won ₹${prizeAmount} (${ticket.multiplier}x multiplier) — ${result.matchCount} matches (${result.tier})`);
          }
        } catch (err) {
          console.error("[lottery] failed to update user wins:", err.message);
        }

        ticket.winAmount = prizeAmount;
        await ticket.save();
      }

      try {
        if (email) await checkLossRecovery(email, result.result === "WIN");
      } catch (_) {}
    }

    let winType   = "normal";
    const winRoll = Math.random();
    if (winRoll < 0.15)      winType = "rare";
    else if (winRoll < 0.30) winType = "popular";

    draw.winningNumbers = winningNumbers;
    draw.status         = "DRAWN";
    draw.totalWinners   = totalWinners;
    draw.drawnAt        = new Date();
    draw.winType        = winType;
    await draw.save();

    return { drawNumber, winningNumbers, totalTickets: tickets.length, totalWinners, winType };
  }
}

module.exports = new LotteryService();