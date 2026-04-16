const crypto = require("crypto");

// ── Symbols & their multipliers ───────────────────────────────
// Each symbol has a payout multiplier and a weight (higher = more common)
const SYMBOLS = [
  { name: "cherry",   multiplier: 2,  weight: 25 },
  { name: "lemon",    multiplier: 3,  weight: 22 },
  { name: "orange",   multiplier: 5,  weight: 18 },
  { name: "bell",     multiplier: 10, weight: 13 },
  { name: "star",     multiplier: 25, weight: 10 },
  { name: "diamond",  multiplier: 50, weight: 12 },
];

const GRID_SIZE = 9; // 3x3 grid
const MATCH_COUNT = 3; // need 3 matching symbols to win

// ── Weighted random symbol pick ───────────────────────────────
function _pickSymbol() {
  const totalWeight = SYMBOLS.reduce((sum, s) => sum + s.weight, 0);
  let rand = crypto.randomInt(0, totalWeight);

  for (const symbol of SYMBOLS) {
    rand -= symbol.weight;
    if (rand < 0) return symbol;
  }
  return SYMBOLS[0]; // fallback
}

// ── Generate a scratch card ───────────────────────────────────
// Returns a 9-cell grid (3x3) with random symbols
function generateCard() {
  const cells = [];
  for (let i = 0; i < GRID_SIZE; i++) {
    cells.push(_pickSymbol().name);
  }
  return cells;
}

// ── Evaluate a scratch card ───────────────────────────────────
// WIN only if 3 or more diamonds appear
function evaluateCard(cells) {
  const diamondCount = cells.filter(c => c === "diamond").length;

  if (diamondCount >= MATCH_COUNT) {
    const diamond = SYMBOLS.find(s => s.name === "diamond");
    return {
      result: "WIN",
      symbol: "diamond",
      matchCount: diamondCount,
      multiplier: diamond.multiplier,
    };
  }

  return {
    result: "LOSE",
    symbol: null,
    matchCount: 0,
    multiplier: 0,
  };
}

// ── Full scratch play: generate + evaluate ────────────────────
function play() {
  const cells = generateCard();
  const outcome = evaluateCard(cells);

  return {
    cells,
    ...outcome,
  };
}

module.exports = {
  generateCard,
  evaluateCard,
  play,
  SYMBOLS,
  GRID_SIZE,
  MATCH_COUNT,
};
