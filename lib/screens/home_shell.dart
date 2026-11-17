import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'events_screen.dart';
import 'live_screen.dart';
import 'summary_screen.dart';

/// Root screen holding the 3 bottom tabs and persisted settings (server IP, sound, vibration).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  // Defaults: localhost for Chrome web dev, LAN IP placeholder for physical Android phone.
  String _host = kIsWeb ? 'localhost:8000' : '192.168.1.10:8000';
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _host = prefs.getString('server_host') ?? _host;
      _soundEnabled = prefs.getBool('alert_sound') ?? true;
      _vibrateEnabled = prefs.getBool('alert_vibrate') ?? true;
      _prefsLoaded = true;
    });
  }

  Future<void> _openSettingsDialog() async {
    final hostController = TextEditingController(text: _host);
    bool tempSound = _soundEnabled;
    bool tempVibrate = _vibrateEnabled;
    String? healthMessage;
    bool checking = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: hostController,
                      decoration: const InputDecoration(
                        labelText: 'Backend Host & Port',
                        hintText: '192.168.1.10:8000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: checking
                              ? null
                              : () async {
                                  setDialogState(() {
                                    checking = true;
                                    healthMessage = null;
                                  });
                                  final ok = await ApiService(hostController.text).checkHealth();
                                  setDialogState(() {
                                    checking = false;
                                    healthMessage =
                                        ok ? 'Connected (/api/health OK)' : 'Could not reach server';
                                  });
                                },
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text('Test Connection'),
                        ),
                      ],
                    ),
                    if (healthMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          healthMessage!,
                          style: TextStyle(
                            color: healthMessage!.contains('OK') ? Colors.green : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Divider(),
                    const Text(
                      'Alert Feedback (Banner always shows)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alert Sound'),
                      value: tempSound,
                      onChanged: (v) => setDialogState(() => tempSound = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibration'),
                      value: tempVibrate,
                      onChanged: (v) => setDialogState(() => tempVibrate = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final newHost = hostController.text.trim();
                    await prefs.setString('server_host', newHost);
                    await prefs.setBool('alert_sound', tempSound);
                    await prefs.setBool('alert_vibrate', tempVibrate);

                    if (!mounted) return;
                    setState(() {
                      _host = newHost;
                      _soundEnabled = tempSound;
                      _vibrateEnabled = tempVibrate;
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // IndexedStack keeps the WebSocket alive on the Live tab even while viewing Charts or History.
    final pages = [
      LiveScreen(
        host: _host,
        soundEnabled: _soundEnabled,
        vibrateEnabled: _vibrateEnabled,
      ),
      SummaryScreen(host: _host),
      EventsScreen(host: _host),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posture Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Server & Alert Settings',
            onPressed: _openSettingsDialog,
          ),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sensors), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Charts'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Alerts'),
        ],
      ),
    );
  }
}