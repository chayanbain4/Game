// ── Fake-padded game stats ────────────────────────────────────
// Always returns totalPlayers >= 500, with realistic win/loss split.
// Real player counts are included in the total.

function padGameStats(realPlayers = 0, realWinners = 0) {
  const minPlayers = 500;
  const extra = Math.floor(Math.random() * 301) + 200; // 200-500 extra
  const totalPlayers = Math.max(realPlayers, minPlayers) + extra;

  // Realistic win rate: 15-30% of total
  const winRate = 0.15 + Math.random() * 0.15;
  let totalWinners = Math.max(realWinners, Math.floor(totalPlayers * winRate));
  if (totalWinners >= totalPlayers) totalWinners = Math.floor(totalPlayers * 0.25);
  const totalLosers = totalPlayers - totalWinners;

  return { totalPlayers, totalWinners, totalLosers };
}

module.exports = { padGameStats };
