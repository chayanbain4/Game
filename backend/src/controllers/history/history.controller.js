const ScratchResult = require("../../models/scratch/scratchResult.model");
const AndarBaharGame = require("../../models/andarbahar/andarbaharGame.model");
const LotteryTicket = require("../../models/lottery/lotteryTicket.model");
const SuperLotoTicket = require("../../models/superloto/superlotoTicket.model");
const LudoGameResult = require("../../models/ludo/ludoGameResult.model");

// GET /api/history/:userId
exports.getFullHistory = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 50;

    const [scratch, andarbahar, lottery, superloto, ludoRaw] = await Promise.all([
      ScratchResult.find({ userId }).sort({ createdAt: -1 }).limit(limit).lean(),
      AndarBaharGame.find({ userId }).sort({ createdAt: -1 }).limit(limit).lean(),
      LotteryTicket.find({ userId }).sort({ createdAt: -1 }).limit(limit).lean(),
      SuperLotoTicket.find({ userId }).sort({ createdAt: -1 }).limit(limit).lean(),
      LudoGameResult.find({ "players.userId": userId }).sort({ createdAt: -1 }).limit(limit).lean(),
    ]);

    // Flatten ludo results into per-user view
    const ludo = ludoRaw.map(g => {
      const me = g.players.find(p => p.userId === userId);
      return {
        ...g,
        result: me ? me.result : "LOSE",
        opponent: g.players.find(p => p.userId !== userId)?.username || "Unknown",
      };
    });

    res.json({
      success: true,
      data: { scratch, andarbahar, lottery, superloto, ludo },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
