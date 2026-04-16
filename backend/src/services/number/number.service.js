const NumberEngine = require("../../game/number/number.engine")

class NumberService {

    playNumberGame(userNumber){

        const result = NumberEngine.checkResult(userNumber)

        return result
    }

}

module.exports = new NumberService()