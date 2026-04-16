class GameModel {

  final String roomCode;
  final int currentTurn;
  final Map<String,List<int>> tokens;

  GameModel({
    required this.roomCode,
    required this.currentTurn,
    required this.tokens,
  });

  factory GameModel.fromJson(Map<String,dynamic> json){

    return GameModel(
      roomCode: json['roomCode'],
      currentTurn: json['currentTurn'],
      tokens: Map<String,List<int>>.from(
        json['tokens'].map(
          (k,v)=> MapEntry(k, List<int>.from(v))
        ),
      ),
    );

  }

}