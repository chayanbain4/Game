import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  IO.Socket? _socket;

  // Change this to your machine's LAN IP for physical device testing
  // e.g. "http://192.168.1.100:4000"
static const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: bool.fromEnvironment('dart.vm.product')
      ? 'https://game.iwebgenics.com'
      : 'http://10.0.2.2:4017',
);

  IO.Socket get socket {
    if (_socket == null) {
      throw StateError('SocketService not connected. Call connect() first.');
    }
    return _socket!;
  }

  bool get isConnected => _socket?.connected ?? false;

  void connect(String userId) {
    // Disconnect existing socket if any
    _socket?.disconnect();

    _socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': userId}) // TODO: Replace with JWT token after auth integration
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('[Socket] Connected as $userId');
    });

    _socket!.onDisconnect((_) {
      print('[Socket] Disconnected');
    });

    _socket!.onConnectError((err) {
      print('[Socket] Connection error: $err');
    });

    _socket!.onError((err) {
      print('[Socket] Error: $err');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
