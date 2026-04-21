# 🎮 Multi-Game Mobile Platform

A cross-platform mobile gaming application built with **Flutter** and powered by a **Node.js** backend. Features multiple real-time games with live score tracking, leaderboards, and Socket.IO-powered multiplayer support.

---

## 🕹️ Games Included

| Game | Type |
|---|---|
| 🎲 Ludo | Multiplayer Board Game |
| 🃏 Andar Bahar | Card Game |
| 🎰 Roulette | Casino-style Game |
| 🎫 Scratch Card | Instant Win Game |
| 🔢 Number Game | Prediction Game |
| 🏆 Lottery | Draw-based Game |
| 💰 Super Loto | Jackpot Game |

---

## 🛠️ Tech Stack

### Frontend (Mobile)
- **Flutter** — Cross-platform UI (Android & iOS)
- **Dart** — App logic
- **Provider** — State management
- **Socket.IO (Dart client)** — Real-time game events

### Backend
- **Node.js + Express.js** — REST API server
- **MongoDB** — Player data, game history, leaderboards
- **Socket.IO** — Real-time multiplayer communication
- **Redis** — Session caching
- **JWT** — Authentication & authorization

---

## 📁 Project Structure

```
LUDO-ANDROID/
├── backend/
│   └── src/
│       ├── config/          # DB, mailer, Redis, game fees config
│       ├── controllers/     # Game logic controllers (ludo, andarbahar, etc.)
│       ├── middlewares/     # Auth middleware
│       ├── models/          # MongoDB schemas
│       ├── routes/          # API route definitions
│       ├── services/        # Business logic services
│       ├── sockets/         # Socket.IO event handlers per game
│       ├── utils/           # Helper functions
│       ├── app.js
│       └── server.js
│
└── frontend/
    └── lib/
        ├── config/          # API config
        ├── core/socket/     # Socket service
        ├── models/          # Dart data models
        ├── providers/       # State management
        ├── screens/         # UI screens per game
        ├── services/        # API service calls
        ├── widgets/         # Reusable UI components
        └── main.dart
```

---

## ✨ Features

- 🎮 7 different games in one app
- 🔴 Real-time multiplayer via Socket.IO
- 🔐 JWT authentication with refresh tokens
- 📊 Game history and leaderboards
- 🎁 Daily rewards system
- 🔔 Engagement notifications
- 📱 Cross-platform (Android & iOS)
- ⚡ Redis-powered session caching

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x+)
- Node.js (18.x+)
- MongoDB
- Redis

### Backend Setup

```bash
cd backend
npm install
```

Create a `.env` file:
```env
PORT=4017
MONGO_URI=your_mongodb_uri
JWT_SECRET=your_jwt_secret
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email
SMTP_PASS=your_password
```

Start the server:
```bash
node src/server.js
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

Update `lib/config/api_config.dart` with your backend URL.

---

## 📸 Screenshots

> *Coming soon — screenshots of gameplay*

---

## 👨‍💻 Author

**Chayan Bain**
- GitHub: [@chayanbain4](https://github.com/chayanbain4)
- LinkedIn: [linkedin.com/in/chayanbain4](https://linkedin.com/in/chayanbain4)

---

## 📝 License

This project is for portfolio demonstration purposes.
Source code is private — company project built at iWebGenics Pvt. Ltd.
