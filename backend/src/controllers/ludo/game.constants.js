const { getGame } = require("../../game/ludo/game.state")

function getGameState(req,res){

 const { roomCode } = req.params

 const game = getGame(roomCode)

 if(!game){
  return res.status(404).json({
   message:"Game not found"
  })
 }

 res.json(game)
}

module.exports = {
 getGameState
}