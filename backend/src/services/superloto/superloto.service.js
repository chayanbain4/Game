const SuperLotoEngine = require("../../game/superloto/superloto.engine");
const SuperLotoDraw   = require("../../models/superloto/superlotoDraw.model");
const SuperLotoTicket = require("../../models/superloto/superlotoTicket.model");
const User            = require("../../models/auth/user.model");
const { shouldBoost, incrementGamesPlayed } = require("../engagement/earlyBoost");
const { checkAndAward }     = require("../engagement/smallRewards");
const { checkLossRecovery } = require("../engagement/lossRecovery");
const { getLuckyNumbers }   = require("../../utils/luckyNumbers");
const FEES = require("../../config/gameFees");

// ── Per-game field names ──────────────────────────────────────────────────────
const GAME_FIELD = "superlotoGamesPlayed";
const LOSS_FIELD = "superlotoLossStreak";

// ── Allowed multipliers ───────────────────────────────────────────────────────
const ALLOWED_MULTIPLIERS = [1, 2, 5, 10];

// ── Win rate table ────────────────────────────────────────────────────────────
const WIN_RATE_TABLE = [
  { minGames:  0, maxGames:   3, winRate: 0.97 },
  { minGames:  4, maxGames:  10, winRate: 0.60 },
  { minGames: 11, maxGames:  20, winRate: 0.50 },
  { minGames: 21, maxGames:  40, winRate: 0.40 },
  { minGames: 41, maxGames: Infinity, winRate: 0.20 },
];

const ATTRACTION_LOSS_TRIGGER = 7;

function getWinRate(gamesPlayed) {
  for (const tier of WIN_RATE_TABLE) {
    if (gamesPlayed >= tier.minGames && gamesPlayed <= tier.maxGames) {
      return tier.winRate;
    }
  }
  return 0.20;
}

class SuperLotoService {

  // ── Buy a ticket ──────────────────────────────────────────────
  // multiplier: 1 | 2 | 5 | 10  (default 1)
  // fee   = ₹2 × 6 numbers × multiplier
  // prize = base prize × multiplier
  async buyTicket(userId, username, numbers, drawNumber, useFreeSpins, multiplier = 1) {
    // Validate multiplier
    const mult = ALLOWED_MULTIPLIERS.includes(Number(multiplier))
      ? Number(multiplier)
      : 1;

    let chosenNumbers = numbers;
    let isQuickPick   = false;

    if (!chosenNumbers || chosenNumbers.length === 0) {
      chosenNumbers = SuperLotoEngine.quickPick();
      isQuickPick   = true;
    }

    const validation = SuperLotoEngine.validateNumbers(chosenNumbers);
    if (!validation.valid) throw new Error(validation.reason);

    // Fee = base (₹2 × 6) × multiplier
    const baseFee = FEES.SUPERLOTO * chosenNumbers.length;   // ₹12
    const fee     = baseFee * mult;                          // ₹12 / ₹24 / ₹60 / ₹120

    const email   = String(userId || "").trim().toLowerCase();
    const userDoc = await User.findOne({ email });
    if (!userDoc) throw new Error("User not found");

    let freeSpinUsed = false;
    if (useFreeSpins && (userDoc.freeSpins || 0) > 0) {
      userDoc.freeSpins -= 1;
      freeSpinUsed = true;
    } else {
      if (userDoc.balance < fee) {
        throw new Error(`Insufficient balance. Need ₹${fee}, have ₹${userDoc.balance}`);
      }
      userDoc.balance -= fee;
    }
    await userDoc.save();

    const draw = await SuperLotoDraw.findOne({ drawNumber });
    if (!draw)                  throw new Error("Draw not found");
    if (draw.status !== "OPEN") throw new Error("This draw is no longer accepting tickets");

    const ticket = await SuperLotoTicket.create({
      userId,
      username:   username || "Anonymous",
      drawNumber,
      numbers:    chosenNumbers.sort((a, b) => a - b),
      isQuickPick,
      multiplier: mult,   // stored on ticket so executeDraw can use it
    });

    await SuperLotoDraw.updateOne({ drawNumber }, { $inc: { totalTickets: 1 } });

    const reward = await checkAndAward(email, false);

    const updatedUser = await User.findOne({ email });
    const newBalance  = updatedUser ? updatedUser.balance : null;

    return {
      ticket,
      reward,
      newBalance,
      freeSpinUsed,
      freeSpins: updatedUser ? (updatedUser.freeSpins || 0) : 0,
      multiplier: mult,
      fee,
    };
  }

  async getCurrentDraw() {
    return SuperLotoDraw.findOne({ status: "OPEN" }).sort({ drawNumber: -1 });
  }

  async getDraw(drawNumber) {
    return SuperLotoDraw.findOne({ drawNumber });
  }

  async getUserTickets(userId, drawNumber) {
    return SuperLotoTicket.find({ userId, drawNumber }).sort({ createdAt: -1 });
  }

  async getUserHistory(userId, limit) {
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    return SuperLotoTicket.find({ userId }).sort({ createdAt: -1 }).limit(safeLimit);
  }

  async getRecentDraws(limit) {
    const safeLimit = Math.min(Math.max(limit || 10, 1), 50);
    return SuperLotoDraw.find({ status: "DRAWN" }).sort({ drawNumber: -1 }).limit(safeLimit);
  }

  // ── Execute draw ──────────────────────────────────────────────
  async executeDraw(drawNumber) {
    const draw = await SuperLotoDraw.findOne({ drawNumber });
    if (!draw)                   throw new Error("Draw not found");
    if (draw.status === "DRAWN") throw new Error("Draw already completed");

    const winningNumbers = SuperLotoEngine.drawWinningNumbers();
    const tickets        = await SuperLotoTicket.find({ drawNumber });

    let totalWinners = 0;

    for (const ticket of tickets) {
      const result = SuperLotoEngine.checkTicket(ticket.numbers, winningNumbers);
      const email  = String(ticket.userId || "").trim().toLowerCase();

      // Per-ticket multiplier — use Number() so undefined/null safely defaults to 1.
      // If the model file was not updated, Mongoose strips the field and it
      // arrives as undefined here; Number(undefined) = NaN, not in the array → 1.
      const mult = ALLOWED_MULTIPLIERS.includes(Number(ticket.multiplier))
        ? Number(ticket.multiplier)
        : 1;

      console.log(`[superloto] ticket multiplier raw=${ticket.multiplier} resolved=${mult}x`);

      const userDoc = await User.findOne({ email })
        .select(`${GAME_FIELD} ${LOSS_FIELD}`)
        .lean();

      const superlotoGamesPlayed = userDoc ? (userDoc[GAME_FIELD] || 0) : 0;
      const superlotoLossStreak  = userDoc ? (userDoc[LOSS_FIELD] || 0) : 0;
      const winRate              = getWinRate(superlotoGamesPlayed);
      const roll                 = Math.random();

      // ── Priority 1: early boost ───────────────────────────────
      const earlyUser = await shouldBoost(ticket.userId, GAME_FIELD);
      if (earlyUser && result.result === "LOSE") {
        result.matchedNumbers = winningNumbers.slice(0, 3);
        result.matchCount     = 3;
        result.result         = "WIN";
        result.tier           = "TIER_3";
        result.tierLabel      = "Tier 3 — 3 numbers matched";
        console.log(`[superloto] 🚀 Early boost for ${email} — forced TIER_3`);

      // ── Priority 2: attraction burst ──────────────────────────
      } else if (superlotoLossStreak >= ATTRACTION_LOSS_TRIGGER && result.result === "LOSE") {
        result.matchedNumbers = winningNumbers.slice(0, 3);
        result.matchCount     = 3;
        result.result         = "WIN";
        result.tier           = "TIER_3";
        result.tierLabel      = "Tier 3 — 3 numbers matched";
        console.log(`[superloto] ⚡ Attraction burst for ${email} — forced TIER_3`);
        await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });

      // ── Priority 3: win rate table ────────────────────────────
      } else if (!earlyUser) {
        const shouldWin = roll < winRate;
        if (shouldWin && result.result === "LOSE") {
          result.matchedNumbers = winningNumbers.slice(0, 3);
          result.matchCount     = 3;
          result.result         = "WIN";
          result.tier           = "TIER_3";
          result.tierLabel      = "Tier 3 — 3 numbers matched";
          console.log(`[superloto] ✅ Win-rate boost for ${email} — forced TIER_3`);
        }
      }

      await incrementGamesPlayed(ticket.userId, GAME_FIELD);

      // Update loss streak
      if (superlotoLossStreak < ATTRACTION_LOSS_TRIGGER) {
        if (result.result === "WIN") {
          await User.updateOne({ email }, { $set: { [LOSS_FIELD]: 0 } });
        } else {
          await User.updateOne({ email }, { $inc: { [LOSS_FIELD]: 1 } });
        }
      }

      // Near-miss on losing tickets
      if (result.result === "LOSE" && result.matchCount <= 1) {
        const nearNums = [];
        const matched  = [];
        const used     = new Set();
        const winSet   = new Set(winningNumbers);

        for (let i = 0; i < 2; i++) {
          nearNums.push(winningNumbers[i]);
          matched.push(winningNumbers[i]);
          used.add(winningNumbers[i]);
        }
        for (let i = 2; i < winningNumbers.length; i++) {
          const off = Math.random() < 0.5 ? 1 : -1;
          let near  = winningNumbers[i] + off;
          if (near < 1 || near > 49 || winSet.has(near) || used.has(near)) near = winningNumbers[i] - off;
          if (near < 1 || near > 49 || used.has(near)) near = winningNumbers[i] + (off === 1 ? 2 : -2);
          if (near > 49) near = winningNumbers[i] - 2;
          if (near < 1)  near = 3;
          used.add(near);
          nearNums.push(near);
        }
        ticket.numbers        = nearNums.sort((a, b) => a - b);
        result.matchedNumbers = matched.sort((a, b) => a - b);
        result.matchCount     = 2;
      }

      ticket.matchedNumbers = result.matchedNumbers;
      ticket.matchCount     = result.matchCount;
      ticket.result         = result.result;
      ticket.tier           = result.tier;
      ticket.tierLabel      = result.tierLabel;
      await ticket.save();

      if (result.result === "WIN") {
        totalWinners++;

        // Base prize × multiplier
        let prizeAmount = ((FEES.WIN_REWARDS.SUPERLOTO[result.tier]) || 0) * mult;

        console.log(`[superloto] ${email} wins — tier=${result.tier} mult=${mult}x prize=₹${prizeAmount}`);

        try {
          const lucky      = getLuckyNumbers(ticket.userId);
          const luckyMatch = result.matchedNumbers.some(n => lucky.includes(n));
          if (luckyMatch) {
            const bonus = Math.round(prizeAmount * 0.5);
            prizeAmount += bonus;
            console.log(`[superloto] ${ticket.userId} lucky bonus +₹${bonus}`);
          }
        } catch (_) {}

        try {
          if (email) {
            await User.findOneAndUpdate(
              { email },
              { $inc: { wins: 1, balance: prizeAmount } }
            );
          }
        } catch (err) {
          console.error("[superloto] failed to update user wins:", err.message);
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

module.exports = new SuperLotoService();