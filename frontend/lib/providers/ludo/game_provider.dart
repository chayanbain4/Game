// lib/providers/ludo/game_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/socket/socket_service.dart';
import '../../services/user_session.dart';

class GameProvider extends ChangeNotifier {

  // ── Game state ────────────────────────────────────────────
  int    dice        = 0;
  int    currentTurn = 0;
  Map<String, List<int>> tokens = {
    'red':    [0, 0, 0, 0],
    'blue':   [0, 0, 0, 0],
    'green':  [0, 0, 0, 0],
    'yellow': [0, 0, 0, 0],
  };
  List<dynamic> players    = [];
  String?       myColor;
  bool          gameStarted = false;
  bool          gameOver    = false;
  String?       winner;
  int           winAmount   = 0;
  String?       lastError;
  bool          myTurn      = false;
  bool          diceRolled  = false;

  // ── Player profiles (real or fake bot profiles) ───────────
  // Key = userId/botId, Value = { name, wins }
  // Client code reads these for display — never knows if it's a bot
  Map<String, dynamic> playerProfiles = {};

  /// Opponent display name (resolved from playerProfiles)
  String get opponentName {
    for (final p in players) {
      if (p['id'].toString() != _myUserId) {
        final profile = playerProfiles[p['id'].toString()];
        return profile?['name']?.toString() ?? 'Opponent';
      }
    }
    return 'Opponent';
  }

  /// Opponent win count (resolved from playerProfiles)
  int get opponentWins {
    for (final p in players) {
      if (p['id'].toString() != _myUserId) {
        final profile = playerProfiles[p['id'].toString()];
        return (profile?['wins'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  /// My display name
  String get myName {
    if (_myUserId == null) return 'You';
    final profile = playerProfiles[_myUserId!];
    return profile?['name']?.toString() ?? _myUserId ?? 'You';
  }

  /// My win count from profiles
  int get myProfileWins {
    if (_myUserId == null) return 0;
    final profile = playerProfiles[_myUserId!];
    return (profile?['wins'] as num?)?.toInt() ?? 0;
  }

  // ── Opponent disconnect ───────────────────────────────────
  bool    opponentLeft    = false;
  String? opponentMessage;

  // ── Turn countdown (UI only) ──────────────────────────────
  Timer? _countdownTimer;
  int    timeLeft = 15;

  bool    _listenersAttached = false;
  String? _myUserId;

  // ─────────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    timeLeft = 15;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        timeLeft--;
        notifyListeners();
      } else {
        t.cancel();
      }
    });
  }

  // ── Attach socket listeners ───────────────────────────────
  // NOTE: game_started is handled in LudoLobbyScreen which then
  // calls initFromData(). Do NOT listen here to avoid double-init.
  void attachListeners(String myUserId) {
    if (_listenersAttached) return;
    _listenersAttached = true;
    _myUserId = myUserId;

    final socket = SocketService().socket;

    // dice_result — fires when rolling player has a valid move
    // (works for BOTH real player and bot rolls)
    socket.on('dice_result', (data) {
      final newDice = (data['dice'] as num).toInt();
      final newTurn = (data['turn'] as num).toInt();

      // Ignore stale events from a previous turn
      if (newTurn != currentTurn) return;

      dice        = newDice;
      currentTurn = newTurn;
      diceRolled  = true;
      lastError   = null;
      _updateMyTurn();
      _startCountdown();
      notifyListeners();
    });

    // game_state — full state after every move_token (real or bot)
    socket.on('game_state', (data) {
      _handleGameState(data);
    });

    // turn_skipped — player/bot rolled but has no valid move
    socket.on('turn_skipped', (data) {
      dice        = (data['dice'] as num?)?.toInt() ?? 0;
      currentTurn = (data['nextTurn'] as num).toInt();
      diceRolled  = false;
      lastError   = (data['reason'] as String?) ?? 'Turn skipped';
      _updateMyTurn();
      _startCountdown();
      notifyListeners();
    });

    // turn_timeout — backend 15s timer expired
    socket.on('turn_timeout', (data) {
      currentTurn = (data['turn'] as num).toInt();
      dice        = 0;
      diceRolled  = false;
      lastError   = 'Time ran out!';
      _updateMyTurn();
      _startCountdown();
      notifyListeners();
    });

    // invalid_move
    socket.on('invalid_move', (data) {
      lastError = (data['message'] as String?) ?? 'Invalid move';
      notifyListeners();
    });

    // player_won — real player OR bot wins
    // If bot wins: winner != _myUserId so no balance update (correct)
    // If user wins: updates local wins + balance
    socket.on('player_won', (data) async {
      winner   = data['player']?.toString();
      gameOver = true;
      _countdownTimer?.cancel();

      final rawCount = data['newWinCount'];
      if (winner == _myUserId && rawCount != null) {
        await UserSession.instance.setWins((rawCount as num).toInt());
      }

      final newBalance = (data['newBalance'] as num?)?.toInt();
      if (winner == _myUserId && newBalance != null) {
        UserSession.instance.setBalance(newBalance);
      }

      winAmount = (data['winAmount'] as num?)?.toInt() ?? 0;
      notifyListeners();
    });

    // opponent_left — other player disconnected/left mid-game
    socket.on('opponent_left', (data) async {
      final wins = data['wins'];
      if (wins != null) {
        await UserSession.instance.setWins((wins as num).toInt());
      }
      final newBalance = (data['newBalance'] as num?)?.toInt();
      if (newBalance != null) {
        UserSession.instance.setBalance(newBalance);
      }
      opponentLeft    = true;
      opponentMessage = (data['message'] as String?) ?? 'Your opponent disconnected.';
      gameOver        = true;
      winAmount       = (data['winAmount'] as num?)?.toInt() ?? 0;
      _countdownTimer?.cancel();
      notifyListeners();
    });

    // stats_updated — backward compatibility
    socket.on('stats_updated', (data) async {
      final wins = data['wins'];
      if (wins != null) {
        await UserSession.instance.setWins((wins as num).toInt());
      }
      notifyListeners();
    });
  }

  // ── Detach listeners ──────────────────────────────────────
  void detachListeners() {
    if (!_listenersAttached) return;
    try {
      final socket = SocketService().socket;
      socket.off('dice_result');
      socket.off('game_state');
      socket.off('turn_skipped');
      socket.off('turn_timeout');
      socket.off('invalid_move');
      socket.off('player_won');
      socket.off('opponent_left');
      socket.off('stats_updated');
    } catch (_) {}
    _countdownTimer?.cancel();
    _listenersAttached = false;
    _myUserId = null;
  }

  // ── Internal handlers ─────────────────────────────────────

  void _handleGameState(dynamic data) {
    if (data['tokens'] != null) {
      tokens = Map<String, List<int>>.from(
        (data['tokens'] as Map).map(
          (k, v) => MapEntry(k as String, List<int>.from(v)),
        ),
      );
    }
    currentTurn = (data['currentTurn'] as num?)?.toInt() ?? currentTurn;
    dice        = 0;
    diceRolled  = false;
    lastError   = null;
    _updateMyTurn();
    _startCountdown();
    notifyListeners();
  }

  void _updateMyTurn() {
    if (players.isEmpty || _myUserId == null) return;
    final current = players[currentTurn % players.length];
    myTurn = current['id'].toString() == _myUserId;
  }

  // ── Public init (called by lobby after game_started) ──────
  void initFromData(dynamic data, String myUserId) {
    _myUserId       = myUserId;
    gameStarted     = true;
    gameOver        = false;
    winner          = null;
    winAmount       = 0;
    opponentLeft    = false;
    opponentMessage = null;
    players         = List<dynamic>.from(data['players'] ?? []);
    currentTurn     = (data['currentTurn'] as num?)?.toInt() ?? 0;
    dice            = 0;
    diceRolled      = false;
    lastError       = null;

    // Parse player profiles (real names + wins, or fake bot names + wins)
    // isBot is never in the payload — client treats all as real players
    if (data['playerProfiles'] != null) {
      playerProfiles = Map<String, dynamic>.from(
        data['playerProfiles'] as Map,
      );
    } else {
      playerProfiles = {};
    }

    myColor = null;
    for (final p in players) {
      if (p['id'].toString() == myUserId) {
        myColor = p['color']?.toString();
        break;
      }
    }

    if (data['tokens'] != null) {
      tokens = Map<String, List<int>>.from(
        (data['tokens'] as Map).map(
          (k, v) => MapEntry(k as String, List<int>.from(v)),
        ),
      );
    }

    _updateMyTurn();
    _startCountdown();
    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────

  void rollDice(String roomCode) {
    if (!myTurn || diceRolled) return;
    lastError = null;
    SocketService().socket.emit('roll_dice', {'roomCode': roomCode});
  }

  void moveToken(String roomCode, int tokenIndex) {
    if (!myTurn || !diceRolled) return;
    lastError = null;
    SocketService().socket.emit('move_token', {
      'roomCode':   roomCode,
      'tokenIndex': tokenIndex,
    });
  }

  // ── Reset ─────────────────────────────────────────────────
  void reset() {
    dice        = 0;
    currentTurn = 0;
    tokens = {
      'red':    [0, 0, 0, 0],
      'blue':   [0, 0, 0, 0],
      'green':  [0, 0, 0, 0],
      'yellow': [0, 0, 0, 0],
    };
    players         = [];
    playerProfiles  = {};
    myColor         = null;
    gameStarted     = false;
    gameOver        = false;
    winner          = null;
    winAmount       = 0;
    opponentLeft    = false;
    opponentMessage = null;
    lastError       = null;
    myTurn          = false;
    diceRolled      = false;
    _myUserId       = null;
    _listenersAttached = false;
    _countdownTimer?.cancel();
  }
}