const {
    startRound,
    addBet,
    getCurrentRound,
    getRemainingTime,
} = require("../../game/number/round.manager")

function initNumberSocket(io){

    io.on("connection",(socket)=>{

        console.log("Number player connected:", socket.id)

        let username  = "Anonymous"
        let userEmail = ""

        /*
        ===========================
        PLAYER JOIN GAME
        ===========================
        */
        socket.on("joinGame",(data)=>{

            if(data && data.username) username  = data.username
            if(data && data.email)    userEmail = data.email

            // ── ADDED THIS LINE SO REWARDS/BALANCE UPDATES WORK ──
            if (userEmail) socket.join(userEmail);

            console.log("Player joined:", username)

            socket.emit("currentRound",{
                round:         getCurrentRound(),
                remainingTime: getRemainingTime(),
            })

        })


        /*
        ===========================
        PLAYER CHOOSE NUMBER
        ===========================
        */
        socket.on("chooseNumber", async (data)=>{

            if(!data) return

            const number       = data.number
            const useFreeSpins = data.useFreeSpins || false

            // Pass userEmail as userId so bet.userId = email and DB lookups work
            const result = await addBet(userEmail, username, number, userEmail, null, useFreeSpins)
            if (result && !result.success) {
                socket.emit("betError", { message: result.message })
                return
            }
            if (result && result.newBalance != null) {
                socket.emit("balance_update", { newBalance: result.newBalance, freeSpins: result.freeSpins })
            }

        })


        /*
        ===========================
        PLAYER DISCONNECT
        ===========================
        */
        socket.on("disconnect",()=>{
            console.log("Player disconnected:", username)
        })

    })

    // start the round engine
    startRound(io)
}

module.exports = initNumberSocket