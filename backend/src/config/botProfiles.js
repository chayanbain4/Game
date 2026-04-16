// src/config/botProfiles.js
// Fake bot identities — client sees these as real players

const BOT_NAMES = [
  "Rahul_G",  "Priya23",   "AkashK",    "Sunita_P", "Rohan99",
  "Deepak_M", "Neha_S",    "Vikram07",  "Anjali_R", "Karan_X",
  "Arjun_21", "Meera_K",   "Saurav_D",  "Pooja_W",  "Ravi_T",
  "Amit_Z",   "Simran_K",  "Nikhil_J",  "Kavya_R",  "Harsh_M",
  "Divya_S",  "Manish_R",  "Sneha_T",   "Rajesh_K", "Priyanka_B",
];

function getFakeBotProfile() {
  const name = BOT_NAMES[Math.floor(Math.random() * BOT_NAMES.length)];
  const wins = Math.floor(Math.random() * 180) + 20; // 20–200 fake wins
  const id   = `BOT_${Date.now()}_${Math.floor(Math.random() * 9999)}`;

  return {
    id,       // internal only — never exposed to client
    name,     // shown to client as opponent name
    wins,     // shown to client as opponent wins
    isBot: true,  // NEVER sent to client
  };
}

module.exports = { getFakeBotProfile };