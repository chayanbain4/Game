class NumberEngine {

    static generateNumber(){
        return Math.floor(Math.random() * 10); // 0 - 9
    }

    static checkResult(userNumber){
        const systemNumber = this.generateNumber()

        const win = userNumber === systemNumber

        return {
            userNumber,
            systemNumber,
            result: win ? "WIN" : "LOSE"
        }
    }

}

module.exports = NumberEngine