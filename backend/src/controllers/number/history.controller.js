const NumberResult = require("../../models/number/numberGame.model")

exports.getHistory = async(req,res)=>{

    try{

        const history = await NumberResult
            .find()
            .sort({createdAt:-1})
            .limit(20)

        res.json({
            success:true,
            data:history
        })

    }catch(err){

        res.status(500).json({
            success:false,
            message:err.message
        })

    }

}