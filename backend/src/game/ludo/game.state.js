const { redis } = require("../../config/redis")

const COLORS = ["red","blue","green","yellow"]

async function createGame(roomCode, players){

 const playerMap = players.map((p,i)=>({
  id:p,
  color:COLORS[i]
 }))

 const game = {

  roomCode,

  players: playerMap,

  currentTurn:0,

  dice:null,

  tokens:{
   red:[0,0,0,0],
   blue:[0,0,0,0],
   green:[0,0,0,0],
   yellow:[0,0,0,0]
  }

 }

 await redis.set(`game:${roomCode}`, JSON.stringify(game))

 return game
}

async function getGame(roomCode){

 const data = await redis.get(`game:${roomCode}`)

 if(!data) return null

 return JSON.parse(data)
}

async function saveGame(roomCode, game){

 await redis.set(`game:${roomCode}`, JSON.stringify(game))
}

async function removeGame(roomCode){

 await redis.del(`game:${roomCode}`)
}

module.exports = {
 createGame,
 getGame,
 saveGame,
 removeGame
}