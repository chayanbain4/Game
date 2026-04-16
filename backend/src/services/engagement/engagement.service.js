const Jackpot = require("../../models/engagement/jackpot.model");
const User    = require("../../models/auth/user.model");

const WELCOME_BONUS_AMOUNT = 100; // ₹100

class EngagementService {

  // ── Get all active jackpots (public) ────────────────────────
  async getActiveJackpots() {
    return Jackpot.find({ isActive: true })
      .sort({ sortOrder: 1 })
      .lean();
  }

  // ── Welcome bonus status ────────────────────────────────────
  async getWelcomeBonusStatus(userId) {
    const user = await User.findById(userId).select("balance welcomeBonusClaimed");
    if (!user) throw new Error("User not found");
    return {
      claimed: user.welcomeBonusClaimed,
      amount: WELCOME_BONUS_AMOUNT,
      displayAmount: `₹${WELCOME_BONUS_AMOUNT}`,
      balance: user.balance,
    };
  }

  // ── Claim welcome bonus ─────────────────────────────────────
  async claimWelcomeBonus(userId) {
    const user = await User.findById(userId);
    if (!user) throw new Error("User not found");
    if (user.welcomeBonusClaimed) {
      throw new Error("Welcome bonus already claimed");
    }

    user.welcomeBonusClaimed = true;
    user.balance += WELCOME_BONUS_AMOUNT;
    await user.save();

    console.log(`[engagement] ${user.email} claimed ₹${WELCOME_BONUS_AMOUNT} welcome bonus`);

    return {
      claimed: true,
      amount: WELCOME_BONUS_AMOUNT,
      displayAmount: `₹${WELCOME_BONUS_AMOUNT}`,
      balance: user.balance,
    };
  }

  // ── Social proof: recent winner feed ───────────────────
  async getRecentWinners() {
    // Pool of realistic Indian names + cities
    const names = [
      "Rahul", "Priya", "Amit", "Sneha", "Vikram", "Anjali", "Arjun",
      "Neha", "Rohit", "Pooja", "Karan", "Divya", "Suresh", "Meena",
      "Rajesh", "Kavita", "Deepak", "Sunita", "Manish", "Ritu",
    ];
    const cities = [
      "Mumbai", "Delhi", "Bangalore", "Chennai", "Kolkata", "Hyderabad",
      "Pune", "Jaipur", "Lucknow", "Ahmedabad", "Chandigarh", "Indore",
      "Bhopal", "Nagpur", "Surat", "Kochi", "Patna", "Guwahati",
    ];
    const games = [
      "Ludo", "Number Game", "Scratch & Win", "Lottery", "Super Loto", "Andar Bahar",
    ];
    const amounts = [100, 200, 300, 500, 800, 1000, 1500, 2000, 2500, 5000];

    const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

    const winners = [];
    for (let i = 0; i < 10; i++) {
      const minsAgo = Math.floor(Math.random() * 30) + 1;
      winners.push({
        name: pick(names),
        city: pick(cities),
        game: pick(games),
        amount: pick(amounts),
        timeAgo: `${minsAgo}m ago`,
      });
    }
    return winners;
  }

  // ── Seed defaults if collection is empty ────────────────────
  async seedDefaults() {
    const count = await Jackpot.countDocuments();
    if (count > 0) return;

    const defaults = [
      {
        name: "Mega Jackpot",
        amount: 420000,
        targetAmount: 500000,
        displayAmount: "₹4,20,000",
        message: "One lucky winner takes it all!",
        icon: "trophy",
        sortOrder: 0,
      },
      {
        name: "Daily Bonus Pool",
        amount: 38000,
        targetAmount: 50000,
        displayAmount: "₹38,000",
        message: "Winners picked every day!",
        icon: "star",
        sortOrder: 1,
      },
      {
        name: "Weekly Grand Prize",
        amount: 72000,
        targetAmount: 100000,
        displayAmount: "₹72,000",
        message: "Play all week & stand a chance!",
        icon: "gift",
        sortOrder: 2,
      },
    ];

    await Jackpot.insertMany(defaults);
    console.log("[engagement] seeded default jackpots");
  }
}

module.exports = new EngagementService();
