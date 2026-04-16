const crypto = require("crypto");

// ── Standard 52-card deck ─────────────────────────────────────
const SUITS  = ["♠", "♥", "♦", "♣"];
const VALUES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

function _buildDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (const value of VALUES) {
      deck.push({ value, suit });
    }
  }
  return deck;
}

// ── Fisher-Yates shuffle with crypto random ───────────────────
function _shuffle(deck) {
  const arr = [...deck];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// ── Play one round of Andar Bahar ─────────────────────────────
// playerChoice is optional ("ANDAR" or "BAHAR"). When provided the
// engine biases the outcome so the player wins roughly 65% of the time.
// If the natural deal goes against the player, we re-deal up to 2 extra
// times — each re-deal has a 50% natural chance, giving ~65% overall.
function play(playerChoice, overrideAttempts) {
  const bias = (playerChoice || "").toUpperCase().trim();
  const maxAttempts = overrideAttempts || (bias ? 2 : 1);

  let best = null;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const result = _dealRound();
    best = result;
    if (!bias || result.winningSide === bias) break; // player wins, done
  }

  return best;
}

function _dealRound() {
  const deck = _shuffle(_buildDeck());

  // 1. Draw the joker card
  const joker = deck.shift();

  // 2. Deal cards alternately: Andar first, then Bahar
  const andarCards = [];
  const baharCards = [];
  let winningSide  = null;
  let matchingCard = null;
  let dealToAndar  = true;

  while (deck.length > 0) {
    const card = deck.shift();

    if (dealToAndar) {
      andarCards.push(card);
    } else {
      baharCards.push(card);
    }

    if (card.value === joker.value) {
      winningSide  = dealToAndar ? "ANDAR" : "BAHAR";
      matchingCard = card;
      break;
    }

    dealToAndar = !dealToAndar;
  }

  const totalDealt = andarCards.length + baharCards.length;

  return {
    joker,
    andarCards,
    baharCards,
    matchingCard,
    winningSide,
    totalDealt,
  };
}

// ── Check if a player's choice matches the winning side ───────
function checkResult(playerChoice, winningSide) {
  const choice = (playerChoice || "").toUpperCase().trim();
  if (choice !== "ANDAR" && choice !== "BAHAR") {
    return { valid: false, reason: "Choice must be ANDAR or BAHAR" };
  }

  const won = choice === winningSide;
  return {
    valid: true,
    result: won ? "WIN" : "LOSE",
    playerChoice: choice,
    winningSide,
  };
}

module.exports = {
  play,
  checkResult,
  SUITS,
  VALUES,
};
