const mongoose = require("mongoose")

const numberResultSchema = new mongoose.Schema({

    round:{
        type:Number,
        required:true
    },

    result:{
        type:Number,
        required:true
    },

    totalPlayers:{
        type:Number,
        default:0
    },

    winType:{
        type:String,
        enum:["normal","rare","popular","no-winner"],
        default:"normal"
    },

    createdAt:{
        type:Date,
        default:Date.now
    }

})

module.exports = mongoose.model("NumberResult",numberResultSchema)