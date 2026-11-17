import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../services/ws_service.dart';

/// Displays real-time posture status and alert banners over WebSocket.
class LiveScreen extends StatefulWidget {
  final String host;
  final bool soundEnabled;
  final bool vibrateEnabled;

  const LiveScreen({
    super.key,
    required this.host,
    required this.soundEnabled,
    required this.vibrateEnabled,
  });

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  WsService? _ws;
  bool _connected = false;
  PostureStatus? _status;
  LiveAlert? _activeAlert;

  @override
  void initState() {
    super.initState();
    _startWebSocket();
  }

  @override
  void didUpdateWidget(covariant LiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reconnect automatically if the user changed the backend IP in Settings.
    if (oldWidget.host != widget.host) {
      _ws?.dispose();
      _startWebSocket();
    }
  }

  void _startWebSocket() {
    _ws = WsService(
      host: widget.host,
      onConnectionChanged: (isConnected) {
        if (mounted) setState(() => _connected = isConnected);
      },
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _status = status;
          // Backend spec: clear the alert banner when status arrives with both alerts false.
          if (!status.postureAlert && !status.distanceAlert) {
            _activeAlert = null;
          }
        });
      },
      onAlert: (alert) {
        if (!mounted) return;
        setState(() => _activeAlert = alert);
        _triggerFeedback();
      },
    )..connect();
  }

  /// Play system alert sound and/or vibrate based on Settings.
  /// Both calls safely no-op on Flutter Web so Chrome dev never crashes.
  void _triggerFeedback() {
    if (widget.soundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
    if (widget.vibrateEnabled) {
      HapticFeedback.vibrate();
    }
  }

  @override
  void dispose() {
    _ws?.dispose();
    super.dispose();
  }

  Color _postureColor(String label) {
    if (label == 'goodposture') return Colors.green;
    if (label == 'unknown') return Colors.grey;
    return Colors.orange.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Connection status pill
        Row(
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: _connected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              _connected
                  ? 'Live (${widget.host})'
                  : 'Reconnecting to ${widget.host}...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Alert Banner (ALWAYS appears when an alert is active, regardless of sound/vibrate)
        if (_activeAlert != null)
          Card(
            color: Colors.red.shade700,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeAlert!.kind.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _activeAlert!.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (_activeAlert != null) const SizedBox(height: 16),

        if (status == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Waiting for Raspberry Pi data...')),
            ),
          )
        else ...[
          // Posture Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Posture', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    prettyLabel(status.label),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _postureColor(status.label),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${status.confidence != null ? '${(status.confidence! * 100).toStringAsFixed(0)}%' : 'N/A'}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Distance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Screen Distance', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        status.distanceCm != null
                            ? '${status.distanceCm!.toStringAsFixed(1)} cm'
                            : 'N/A',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text(status.distanceState.toUpperCase()),
                    backgroundColor: status.distanceState == 'tooclose'
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Last update: ${status.ts.hour.toString().padLeft(2, '0')}:${status.ts.minute.toString().padLeft(2, '0')}:${status.ts.second.toString().padLeft(2, '0')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ],
    );
  }
}