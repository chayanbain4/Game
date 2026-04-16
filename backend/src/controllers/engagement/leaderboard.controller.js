const ScratchResult   = require("../../models/scratch/scratchResult.model");
const AndarBaharGame  = require("../../models/andarbahar/andarbaharGame.model");
const LotteryTicket   = require("../../models/lottery/lotteryTicket.model");
const SuperLotoTicket = require("../../models/superloto/superlotoTicket.model");
const LudoGameResult  = require("../../models/ludo/ludoGameResult.model");
const { WIN_REWARDS } = require("../../config/gameFees");

// GET /api/engagement/leaderboard
exports.getLeaderboard = async (_req, res) => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const todayFilter = { createdAt: { $gte: startOfDay } };

    // Run all queries in parallel
    const [scratch, andarbahar, lottery, superloto, ludo] = await Promise.all([
      ScratchResult.find({ ...todayFilter, result: "WIN" })
        .select("userId username")
        .lean(),
      AndarBaharGame.find({ ...todayFilter, result: "WIN" })
        .select("userId username")
        .lean(),
      LotteryTicket.find({ ...todayFilter, result: "WIN" })
        .select("userId username winAmount")
        .lean(),
      SuperLotoTicket.find({ ...todayFilter, result: "WIN" })
        .select("userId username winAmount")
        .lean(),
      LudoGameResult.find({
        ...todayFilter,
        "players.result": "WIN",
      })
        .select("players")
        .lean(),
    ]);

    // Accumulate per-user winnings: { [userId]: { name, total } }
    const board = {};

    const add = (userId, name, amount) => {
      if (!userId) return;
      if (!board[userId]) board[userId] = { name: name || "Player", total: 0 };
      board[userId].total += amount;
    };

    scratch.forEach((r) => add(r.userId, r.username, WIN_REWARDS.SCRATCH));
    andarbahar.forEach((r) => add(r.userId, r.username, WIN_REWARDS.ANDARBAHAR));
    lottery.forEach((t) => add(t.userId, t.username, t.winAmount || 0));
    superloto.forEach((t) => add(t.userId, t.username, t.winAmount || 0));
    ludo.forEach((g) => {
      const winner = g.players.find((p) => p.result === "WIN");
      if (winner) add(winner.userId, winner.username, WIN_REWARDS.LUDO);
    });

    // Sort descending by total, take top 10
    const leaderboard = Object.entries(board)
      .map(([userId, { name, total }]) => ({ userId, name, total }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 10);

    res.json({ success: true, data: leaderboard });
  } catch (err) {
    console.error("[leaderboard] error:", err.message);
    res.status(500).json({ success: false, message: err.message });
  }
};
