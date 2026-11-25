import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:vibration/vibration.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';

/// Displays real-time posture status, alert banners (with snapshot preview),
/// start/end audio + vibration feedback, Pi connection state, and calibration controls.
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  WsService? _ws;

  bool _connected = false;
  bool _piConnected = false;
  bool _sendingCommand = false;
  PostureStatus? _status;
  LiveAlert? _activeAlert;
  PostureSnapshot? _latestAlertSnapshot;
  CommandResult? _lastCommandResult;

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
        final wasAlertActive = _activeAlert != null;
        final isNowClear = !status.postureAlert && !status.distanceAlert;

        setState(() {
          _status = status;
          // Clear the alert banner when status arrives with both alerts false.
          if (isNowClear) {
            _activeAlert = null;
            _latestAlertSnapshot = null;
          }
        });

        // Play the recovery sound when transitioning from an active alert back to good posture.
        if (wasAlertActive && isNowClear) {
          _playSound('sounds/alert_end.mp3');
        }
      },
      onAlert: (alert) {
        if (!mounted) return;
        setState(() {
          _activeAlert = alert;
          _latestAlertSnapshot = null;
        });
        _playSound('sounds/alert_start.mp3');
        _triggerVibration();
      },
      onSnapshot: (snap) {
        if (!mounted) return;
        final resolvedUrl = ApiService(widget.host).resolveMediaUrl(snap.imageUrl);
        setState(() {
          _latestAlertSnapshot = PostureSnapshot(
            id: snap.id,
            eventId: snap.eventId,
            ts: snap.ts,
            label: snap.label,
            imageUrl: resolvedUrl,
          );
        });
      },
      onDeviceChanged: (piOnline) {
        if (mounted) setState(() => _piConnected = piOnline);
      },
      onCommandResult: (result) {
        if (mounted) setState(() => _lastCommandResult = result);
      },
    )..connect();
  }

  Future<void> _playSound(String assetPath) async {
    if (!widget.soundEnabled) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (_) {
      // Ignore if asset file hasn't been added yet or browser blocks autoplay before user tap
    }
  }

  Future<void> _triggerVibration() async {
    if (!widget.vibrateEnabled || kIsWeb) return;
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 500);
      }
    } catch (_) {
      // Ignore on devices without a vibration motor
    }
  }

  Future<void> _sendCalibration(String command) async {
    setState(() => _sendingCommand = true);
    try {
      await ApiService(widget.host).sendCommand(command);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sendingCommand = false);
    }
  }

  @override
  void dispose() {
    _ws?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Color _postureColor(String label) {
    if (label == 'goodposture') return Colors.green;
    if (label == 'unknown') return Colors.grey;
    return Colors.orange.shade800;
  }

  Color _calibrationStatusColor(String status) {
    switch (status) {
      case 'done':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Connection status pills (Server WS + Raspberry Pi)
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: _connected ? Colors.green : Colors.red),
                const SizedBox(width: 6),
                Text(_connected ? 'Server (${widget.host})' : 'Reconnecting...'),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: _piConnected ? Colors.green : Colors.grey),
                const SizedBox(width: 6),
                Text(_piConnected ? 'Pi Online' : 'Pi Offline'),
              ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  if (_latestAlertSnapshot != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _latestAlertSnapshot!.imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
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
        ],

        // Remote Calibration Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Remote Calibration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_piConnected && !_sendingCommand)
                            ? () => _sendCalibration('calibrate_camera')
                            : null,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_piConnected && !_sendingCommand)
                            ? () => _sendCalibration('calibrate_distance')
                            : null,
                        icon: const Icon(Icons.straighten),
                        label: const Text('Distance'),
                      ),
                    ),
                  ],
                ),
                if (_lastCommandResult != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          _lastCommandResult!.status.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        backgroundColor: _calibrationStatusColor(_lastCommandResult!.status),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastCommandResult!.detail.isNotEmpty
                              ? _lastCommandResult!.detail
                              : _lastCommandResult!.command,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        if (status != null) ...[
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