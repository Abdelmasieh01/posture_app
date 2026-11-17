import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models.dart';

/// Connects to ws://<host>/ws/notifications/ and automatically reconnects if dropped.
class WsService {
  final String host;
  final void Function(bool connected) onConnectionChanged;
  final void Function(PostureStatus status) onStatus;
  final void Function(LiveAlert alert) onAlert;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  WsService({
    required this.host,
    required this.onConnectionChanged,
    required this.onStatus,
    required this.onAlert,
  });

  String get _wsUrl {
    final clean = host
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'^wss?://'), '')
        .replaceAll(RegExp(r'/$'), '');
    return 'ws://$clean/ws/notifications/';
  }

  void connect() {
    if (_disposed) return;
    _cleanupChannel();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      onConnectionChanged(true);

      _sub = _channel!.stream.listen(
        (rawMessage) {
          final map = jsonDecode(rawMessage as String) as Map<String, dynamic>;
          final type = map['type'] as String?;
          final data = map['data'] as Map<String, dynamic>?;
          if (data == null) return;

          if (type == 'status') {
            onStatus(PostureStatus.fromJson(data));
          } else if (type == 'alert') {
            onAlert(LiveAlert.fromJson(data));
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    onConnectionChanged(false);
    _cleanupChannel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }

  void _cleanupChannel() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _cleanupChannel();
  }
}