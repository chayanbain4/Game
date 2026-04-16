// game.engine.js
const crypto = require("crypto");

// ─── Each color enters the board at its OWN cell ─────────────
// Red   → 1   (left side, row 6)
// Blue  → 14  (top side, row 0-1)
// Green → 27  (right side, row 8)
// Yellow→ 40  (bottom side, row 14)
const COLOR_START_POSITIONS = {
  red:    1,
  blue:   14,
  green:  27,
  yellow: 40,
};

const OUTER_TRACK_LENGTH = 52;  // positions 1–52 on outer ring
const WINNING_POSITION   = 57;  // 52 outer + 5 home column steps
const SAFE_CELLS         = [1, 9, 14, 22, 27, 35, 40, 48];

// ── Cryptographically fair dice ───────────────────────────────
function rollDice() {
  return crypto.randomInt(1, 7);  // 1–6 inclusive
}

// ── Core move function ────────────────────────────────────────
// position  : 0 = base, 1–52 = outer ring, 53–57 = home column
// diceValue : 1–6
// color     : 'red' | 'blue' | 'green' | 'yellow'
// returns   : new position (number), or null if move is not valid
function moveToken(position, diceValue, color) {
  const startPos = COLOR_START_POSITIONS[color];

  // ── Already won — cannot move further ───────────────────
  // Must be checked FIRST. A token at WINNING_POSITION (57) stored
  // in game state would otherwise fall through to the home-column
  // branch and always overshoot, locking the token permanently.
  if (position >= WINNING_POSITION) return null;

  // ── In base: need 6 to enter ──────────────────────────────
  if (position === 0) {
    if (diceValue !== 6) return null;
    return startPos;   // ← enter at THIS color's own start cell
  }

  // ── Inside home column (53–56): just add steps ───────────
  if (position > OUTER_TRACK_LENGTH) {
    const newPos = position + diceValue;
    if (newPos > WINNING_POSITION) return null;  // overshoot
    return newPos;
  }

  // ── On outer ring ─────────────────────────────────────────
  // How many steps has this token taken from its own start?
  const stepsTaken = (position - startPos + OUTER_TRACK_LENGTH) % OUTER_TRACK_LENGTH;
  // How many outer steps remain before home column entrance?
  const stepsToHomeEntrance = (OUTER_TRACK_LENGTH - 1) - stepsTaken; // 51 total

  if (diceValue <= stepsToHomeEntrance) {
    // Still on outer ring — wrap around 52 → 1
    return ((position - 1 + diceValue) % OUTER_TRACK_LENGTH) + 1;
  }

  // Entering home column
  const homeStep = diceValue - stepsToHomeEntrance;
  const newPos   = OUTER_TRACK_LENGTH + homeStep;   // e.g. 52+3 = 55
  if (newPos > WINNING_POSITION) return null;        // overshoot
  return newPos;
}

// ── Capture check ─────────────────────────────────────────────
// Returns the color of a captured token at newPos (if any),
// or null if no capture happens.
function checkCapture(game, movingColor, newPos) {
  if (newPos > OUTER_TRACK_LENGTH) return null;  // home column: no captures
  if (SAFE_CELLS.includes(newPos))  return null;  // safe cell: no captures

  for (const [color, positions] of Object.entries(game.tokens)) {
    if (color === movingColor) continue;
    for (let i = 0; i < positions.length; i++) {
      if (positions[i] === newPos) {
        return { color, tokenIndex: i };  // this token gets sent back to base
      }
    }
  }
  return null;
}

// ── Check if a player has won ─────────────────────────────────
function hasWon(tokenPositions) {
  return tokenPositions.every(p => p === WINNING_POSITION);
}

module.exports = {
  rollDice,
  moveToken,
  checkCapture,
  hasWon,
  COLOR_START_POSITIONS,
  WINNING_POSITION,
  SAFE_CELLS,
};