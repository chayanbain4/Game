const NumberResult = require("../../models/number/numberGame.model")
const { shouldBoost, incrementGamesPlayed } = require("../../services/engagement/earlyBoost")
const { checkAndAward }     = require("../../services/engagement/smallRewards")
const { checkLossRecovery } = require("../../services/engagement/lossRecovery")
const User = require("../../models/auth/user.model")
const FEES = require("../../config/gameFees")

// ── Per-game field names ──────────────────────────────────────────────────────
const GAME_FIELD = "numberGamesPlayed"
const LOSS_FIELD = "numberLossStreak"

let currentRound   = 1
const ROUND_TIME   = 15

let currentResult  = null
let isRoundRunning = false

// roundBets stores ALL bet entries.
// Same user can appear MULTIPLE times — each chooseNumber call = 1 new entry = ₹3 deducted.
// e.g. user picks 9 three times → 3 entries, ₹9 deducted total.
// If 9 wins → user gets ₹18 credited (2 × ₹9).
const roundBets    = {}
let roundStartTime = null

// ── Win rate table ────────────────────────────────────────────────────────────
const WIN_RATE_TABLE = [
    { minGames:  0, maxGames:   3, winRate: 0.97 },
    { minGames:  4, maxGames:  10, winRate: 0.60 },
    { minGames: 11, maxGames:  20, winRate: 0.50 },
    { minGames: 21, maxGames:  40, winRate: 0.40 },
    { minGames: 41, maxGames: Infinity, winRate: 0.20 },
]

const ATTRACTION_LOSS_TRIGGER = 7

function getWinRate(gamesPlayed) {
    for (const tier of WIN_RATE_TABLE) {
        if (gamesPlayed >= tier.minGames && gamesPlayed <= tier.maxGames) {
            return tier.winRate
        }
    }
    return 0.20
}

/**
 * Select a winner using win rate.
 * Deduplicates to one entry per user so each user gets exactly one rate-check.
 * Returns one representative bet entry for the winning user, or null.
 */
async function selectWinnerByRate(bets) {
    const seen = new Set()
    const uniqueBets = []
    for (const bet of bets) {
        if (!seen.has(bet.userId)) {
            seen.add(bet.userId)
            uniqueBets.push(bet)
        }
    }

    const shuffled = [...uniqueBets].sort(() => Math.random() - 0.5)

    for (const bet of shuffled) {
        try {
            const emailStr = String(bet.email || bet.userId || "").trim().toLowerCase()
            const userDoc  = await User.findOne({ email: emailStr })
                .select(`${GAME_FIELD} ${LOSS_FIELD}`)
                .lean()

            const gamesPlayed = userDoc ? (userDoc[GAME_FIELD] || 0) : 0
            const lossStreak  = userDoc ? (userDoc[LOSS_FIELD] || 0) : 0
            const winRate     = getWinRate(gamesPlayed)
            const roll        = Math.random()

            if (lossStreak >= ATTRACTION_LOSS_TRIGGER) {
                console.log(`[number] ⚡ Attraction burst for ${emailStr} (lossStreak=${lossStreak}) — forced win`)
                await User.updateOne({ email: emailStr }, { $set: { [LOSS_FIELD]: 0 } })
                return bet
            }

            console.log(`[number] winRate check: ${emailStr} games=${gamesPlayed} rate=${winRate} roll=${roll.toFixed(3)} → ${roll < winRate ? "WIN" : "LOSE"}`)

            if (roll < winRate) return bet

        } catch (_) { /* ignore */ }
    }

    return null
}

// ─────────────────────────────────────────────────────────────────────────────

function startRound(io) {
    if (isRoundRunning) return
    isRoundRunning = true
    console.log("Number game engine started")
    runRound(io)
}

function runRound(io) {
    roundStartTime = Date.now()
    console.log(`Round ${currentRound} started`)

    io.emit("roundStarted", {
        round: currentRound,
        time:  ROUND_TIME,
    })

    setTimeout(async () => {

        let result  = Math.floor(Math.random() * 10)
        let winType = "normal"

        const bets    = roundBets[currentRound] || []
        const betNums = new Set(bets.map(b => b.number))

        // Count total bet entries per number (each entry = 1 bet = ₹3)
        const betCounts = {}
        for (const bet of bets) {
            betCounts[bet.number] = (betCounts[bet.number] || 0) + 1
        }
        const betNumbers = Object.keys(betCounts).map(Number)

        // ── Special event rounds (20%) ────────────────────────────────────────
        const roll = Math.random()

        if (roll < 0.10 && bets.length >= 2 && betNumbers.length >= 2) {
            // 10% — Rare Pick: number with fewest bet entries
            const minCount = Math.min(...betNumbers.map(n => betCounts[n]))
            const rareNums = betNumbers.filter(n => betCounts[n] === minCount)
            result  = rareNums[Math.floor(Math.random() * rareNums.length)]
            winType = "rare"
            console.log(`[number] 🎯 Rare Pick! Number ${result}`)

        } else if (roll < 0.20 && bets.length >= 2 && betNumbers.length >= 2) {
            // 10% — Popular Pick: number with most bet entries
            const maxCount    = Math.max(...betNumbers.map(n => betCounts[n]))
            const popularNums = betNumbers.filter(n => betCounts[n] === maxCount)
            result  = popularNums[Math.floor(Math.random() * popularNums.length)]
            winType = "popular"
            console.log(`[number] 🔥 Popular Pick! Number ${result}`)

        } else {
            // ── Normal round (80%) ────────────────────────────────────────────
            winType = "normal"

            // Step 1: early boost (unique users only)
            let earlyWinner = null
            const seenEarly = new Set()
            for (const bet of bets) {
                if (seenEarly.has(bet.userId)) continue
                seenEarly.add(bet.userId)
                try {
                    const boost = await shouldBoost(bet.userId, GAME_FIELD)
                    if (boost) { earlyWinner = bet; break }
                } catch (_) { /* ignore */ }
            }

            if (earlyWinner) {
                result = earlyWinner.number
                console.log(`[number] 🚀 Early boost: ${earlyWinner.userId} wins on number ${result}`)

            } else if (bets.length > 0) {
                // Step 2: win rate selection
                const winnerBet = await selectWinnerByRate(bets)

                if (winnerBet) {
                    result = winnerBet.number
                    console.log(`[number] ✅ Win-rate winner: ${winnerBet.userId} on number ${result}`)

                } else {
                    // Step 3: no winner — pick unchosen number
                    const unchosen = []
                    for (let n = 0; n <= 9; n++) {
                        if (!betNums.has(n)) unchosen.push(n)
                    }

                    if (unchosen.length > 0) {
                        result  = unchosen[Math.floor(Math.random() * unchosen.length)]
                        winType = "no-winner"
                        console.log(`[number] ❌ No winner. Result ${result}`)

                        // Near-miss nudge
                        const targetBet = bets[Math.floor(Math.random() * bets.length)]
                        const off       = Math.random() < 0.5 ? 1 : -1
                        let near        = (targetBet.number + off + 10) % 10
                        if (!betNums.has(near)) {
                            result = near
                        } else {
                            near = (targetBet.number - off + 10) % 10
                            if (!betNums.has(near)) result = near
                        }
                        console.log(`[number] 🎭 Near-miss result: ${result}`)

                    } else {
                        // All 10 numbers covered — pick least-bet number
                        const minCount = Math.min(...betNumbers.map(n => betCounts[n]))
                        const leastBet = betNumbers.filter(n => betCounts[n] === minCount)
                        result = leastBet[Math.floor(Math.random() * leastBet.length)]
                    }
                }
            }
        }

        // Cosmetic badge for solo/no-bet rounds
        if (winType === "normal" && bets.length < 2) {
            const labelRoll = Math.random()
            if (labelRoll < 0.10)      winType = "rare"
            else if (labelRoll < 0.20) winType = "popular"
            else if (labelRoll < 0.30) winType = "no-winner"
        }

        currentResult = result
        console.log(`Round ${currentRound} result:`, result)

        // ── Winners: all bet entries whose number === result ──────────────────
        const winners = bets.filter(b => b.number === result)

        // ── Increment games played — once per unique user ─────────────────────
        const seenIncrement = new Set()
        for (const bet of bets) {
            if (!seenIncrement.has(bet.userId)) {
                seenIncrement.add(bet.userId)
                incrementGamesPlayed(bet.userId, GAME_FIELD).catch(() => {})
            }
        }

        // ── Update loss streaks — once per unique user ────────────────────────
        const seenStreak = new Set()
        for (const bet of bets) {
            if (seenStreak.has(bet.userId)) continue
            seenStreak.add(bet.userId)

            const didWin   = bet.number === result
            const emailStr = String(bet.email || bet.userId || "").trim().toLowerCase()
            try {
                if (emailStr) {
                    if (didWin) {
                        await User.updateOne({ email: emailStr }, { $set: { [LOSS_FIELD]: 0 } })
                    } else {
                        const u      = await User.findOne({ email: emailStr }).select(LOSS_FIELD).lean()
                        const streak = u ? (u[LOSS_FIELD] || 0) : 0
                        if (streak < ATTRACTION_LOSS_TRIGGER) {
                            await User.updateOne({ email: emailStr }, { $inc: { [LOSS_FIELD]: 1 } })
                        }
                    }
                }
            } catch (_) { /* ignore */ }
        }

        // ── Small rewards + loss recovery — once per unique user ─────────────
        const seenRewards = new Set()
        for (const bet of bets) {
            if (seenRewards.has(bet.userId)) continue
            seenRewards.add(bet.userId)

            const didWin = bet.number === result
            try {
                if (bet.email) {
                    const reward = await checkAndAward(bet.email, didWin)
                    if (reward) io.to(bet.socketId).emit("smallReward", reward)

                    const recovery = await checkLossRecovery(bet.email, didWin)
                    if (recovery) io.to(bet.socketId).emit("lossRecovery", recovery)
                }
            } catch (_) { /* ignore */ }
        }

        console.log("Total bet entries:", bets.length)
        console.log("Winning entries:", winners.length)

        // ── Prize logic ───────────────────────────────────────────────────────
        // Payout = 2 × total amount bet on winning number per user
        //
        // Example:
        //   User bet number 9 → 1 time  → deducted ₹3  → wins ₹6
        //   User bet number 9 → 2 times → deducted ₹6  → wins ₹12
        //   User bet number 9 → 3 times → deducted ₹9  → wins ₹18
        //
        // Group winning entries by user to calculate each user's payout
        const winnerPayouts = {}  // { email: { socketId, betCount } }
        for (const w of winners) {
            const emailStr = String(w.email || w.userId || "").trim().toLowerCase()
            if (!emailStr) continue
            if (!winnerPayouts[emailStr]) {
                winnerPayouts[emailStr] = { socketId: w.socketId, betCount: 0 }
            }
            winnerPayouts[emailStr].betCount += 1
        }

        // Credit each winning user: winAmount = betCount × FEES.NUMBER × 2
        for (const [emailStr, info] of Object.entries(winnerPayouts)) {
            try {
                const winAmount = info.betCount * FEES.NUMBER * 2
                // e.g. 1 bet → 1×3×2 = ₹6 | 2 bets → 2×3×2 = ₹12 | 3 bets → 3×3×2 = ₹18
                const updated = await User.findOneAndUpdate(
                    { email: emailStr },
                    { $inc: { wins: 1, balance: winAmount } },
                    { new: true }
                )
                console.log(`[number] 🏆 ${emailStr} bet ${info.betCount}× on ${result} → won ₹${winAmount}, new balance=₹${updated ? updated.balance : '?'}`)
                io.to(info.socketId).emit("balance_update", {
                    newBalance: updated ? updated.balance : null,
                    winAmount:  winAmount,
                })
            } catch (err) {
                console.log("[number] win credit error:", err.message)
            }
        }

        // Most popular number display
        let mostPopularNumber = result
        let mostPopularCount  = 0
        if (bets.length >= 1) {
            let maxCount = 0
            for (const [num, count] of Object.entries(betCounts)) {
                if (count > maxCount) {
                    maxCount          = count
                    mostPopularNumber = Number(num)
                }
            }
            mostPopularCount = maxCount
        } else {
            mostPopularNumber = Math.floor(Math.random() * 10)
            mostPopularCount  = Math.floor(Math.random() * 8) + 3
        }

        const { padGameStats } = require("../../utils/gameStats")
        const uniquePlayers    = new Set(bets.map(b => b.userId)).size
        const uniqueWinners    = Object.keys(winnerPayouts).length
        const gameStats        = padGameStats(uniquePlayers, uniqueWinners)

        io.emit("roundResult", {
            round:             currentRound,
            result:            result,
            winners:           winners,
            winAmount:         winners.length > 0 ? FEES.NUMBER * 2 : 0,  // per-single-bet win shown in UI
            winType:           winType,
            mostPopularNumber: mostPopularNumber,
            mostPopularCount:  mostPopularCount,
            totalPlayers:      gameStats.totalPlayers,
            totalWinners:      gameStats.totalWinners,
            totalLosers:       gameStats.totalLosers,
        })

        try {
            await NumberResult.create({
                round:        currentRound,
                result:       result,
                totalPlayers: uniquePlayers,
                winType:      winType,
            })
        } catch (err) {
            console.log("History save error:", err.message)
        }

        delete roundBets[currentRound]
        currentRound++

        setTimeout(() => { runRound(io) }, 2000)

    }, ROUND_TIME * 1000)
}

/*
===========================
STORE PLAYER BET
===========================
Each call places ONE new bet entry (costs ₹3).
User can call multiple times on same or different numbers.
No "replace" logic — every call adds a fresh entry.
*/
async function addBet(userId, username, number, email, socketRef, useFreeSpins) {

    if (number < 0 || number > 9) {
        return { success: false, message: "Invalid number. Must be 0–9." }
    }

    const emailStr = String(email || userId || "").trim().toLowerCase()

    try {
        const userDoc = await User.findOne({ email: emailStr })
        if (!userDoc) return { success: false, message: "User not found" }

        if (useFreeSpins && (userDoc.freeSpins || 0) > 0) {
            // Use one free spin for this single bet entry
            userDoc.freeSpins -= 1
        } else {
            if (userDoc.balance < FEES.NUMBER) {
                return {
                    success: false,
                    message: `Insufficient balance. Need ₹${FEES.NUMBER}, have ₹${userDoc.balance}`
                }
            }
            userDoc.balance -= FEES.NUMBER   // deduct ₹3 for this one bet entry
        }

        await userDoc.save()
    } catch (err) {
        console.log("Fee deduction error:", err.message)
        return { success: false, message: "Failed to deduct entry fee" }
    }

    const round = currentRound
    if (!roundBets[round]) roundBets[round] = []

    // Always push a NEW entry — no replace logic
    roundBets[round].push({
        userId,
        username,
        number,
        email:    email || "",
        socketId: userId,
    })

    const userBetCount = roundBets[round].filter(b => b.userId === userId).length
    console.log(`[number] Bet added: ${emailStr} → number ${number} (${userBetCount}× this round) | total entries: ${roundBets[round].length}`)

    try {
        const updatedUser = await User.findOne({ email: emailStr })
        return {
            success:    true,
            newBalance: updatedUser ? updatedUser.balance : null,
            freeSpins:  updatedUser ? (updatedUser.freeSpins || 0) : 0,
        }
    } catch (_) {
        return { success: true, newBalance: null, freeSpins: 0 }
    }
}

/*
===========================
SYNC HELPERS
===========================
*/
function getCurrentRound()  { return currentRound }
function getCurrentResult() { return currentResult }

function getRemainingTime() {
    if (!roundStartTime) return ROUND_TIME
    const elapsed   = Math.floor((Date.now() - roundStartTime) / 1000)
    const remaining = ROUND_TIME - elapsed
    return remaining > 0 ? remaining : 0
}

module.exports = {
    startRound,
    addBet,
    getCurrentRound,
    getCurrentResult,
    getRemainingTime,
}