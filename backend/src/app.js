const express = require("express");
const cors = require("cors");
const path = require("path");

const authRoutes = require("./routes/auth/auth.routes");
const roomRoutes = require("./routes/ludo/room.routes");
const numberRoutes = require('./routes/number/number.routes');
const scratchRoutes = require("./routes/scratch/scratch.routes");
const lotteryRoutes = require("./routes/lottery/lottery.routes");
const superlotoRoutes = require("./routes/superloto/superloto.routes");
const andarbaharRoutes = require("./routes/andarbahar/andarbahar.routes");
const engagementRoutes = require("./routes/engagement/engagement.routes");
const historyRoutes = require("./routes/history/history.routes");
const appUpdateRoutes = require("./routes/appUpdate.routes");
const rouletteRoutes = require("./routes/roulette/roulette.routes"); // ← NEW

const app = express();

app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
    credentials: true,
  })
);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// APK static folder
app.use("/apk", express.static(path.join(__dirname, "../public/apk")));

app.use("/auth", authRoutes);
app.use("/rooms", roomRoutes);
app.use('/number', numberRoutes);
app.use("/api/scratch", scratchRoutes);
app.use("/api/lottery", lotteryRoutes);
app.use("/api/superloto", superlotoRoutes);
app.use("/api/andarbahar", andarbaharRoutes);
app.use("/api/engagement", engagementRoutes);
app.use("/api/history", historyRoutes);
app.use("/api/roulette", rouletteRoutes); // ← NEW
app.use("/api", appUpdateRoutes);

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Android Game Backend is live",
    api_base: "/api",
    health: "/health",
    apk_base: "/apk"
  });
});

app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: "ok",
  });
});

module.exports = app;