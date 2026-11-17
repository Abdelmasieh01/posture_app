import 'package:material_ui/material_ui.dart';
import '../models.dart';
import '../services/api_service.dart';

/// Displays filterable alert history from GET /api/events/.
class EventsScreen extends StatefulWidget {
  final String host;

  const EventsScreen({super.key, required this.host});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _selectedKind = ''; // '' = All, 'posture', 'distance'
  List<AlertEvent> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host) {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService(widget.host).fetchEvents(kind: _selectedKind);
      if (!mounted) return;
      setState(() {
        _events = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _filterChip('All', ''),
              const SizedBox(width: 8),
              _filterChip('Posture', 'posture'),
              const SizedBox(width: 8),
              _filterChip('Distance', 'distance'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadEvents,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [Text('Error loading alerts:\n$_error')],
                      )
                    : _events.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(32),
                            children: const [Center(child: Text('No alert events yet.'))],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _events.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final ev = _events[i];
                              final isStart = ev.state == 'start';
                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    ev.kind == 'distance'
                                        ? Icons.social_distance
                                        : Icons.accessibility_new,
                                    color: isStart ? Colors.red : Colors.green,
                                  ),
                                  title: Text(ev.message),
                                  subtitle: Text(
                                    '${_formatTime(ev.ts)} • ${ev.state.toUpperCase()}'
                                    '${ev.durationS != null ? ' (${ev.durationS!.toStringAsFixed(1)}s)' : ''}',
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String kindValue) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedKind == kindValue,
      onSelected: (_) {
        setState(() => _selectedKind = kindValue);
        _loadEvents();
      },
    );
  }
}