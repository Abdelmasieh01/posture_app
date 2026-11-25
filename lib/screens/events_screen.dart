import 'package:material_ui/material_ui.dart';
import '../models.dart';
import '../services/api_service.dart';

/// Displays filterable alert history from GET /api/events/ paired with JPEG snapshots
/// from GET /api/snapshots/ matched by `event_id`.
class EventsScreen extends StatefulWidget {
  final String host;

  const EventsScreen({super.key, required this.host});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _selectedKind = ''; // '' = All, 'posture', 'distance'
  List<AlertEvent> _events = [];
  Map<String, List<PostureSnapshot>> _snapshotsByEvent = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService(widget.host);
      // Fetch events and snapshots in parallel
      final results = await Future.wait([
        api.fetchEvents(kind: _selectedKind),
        api.fetchSnapshots(),
      ]);

      final events = results[0] as List<AlertEvent>;
      final snapshots = results[1] as List<PostureSnapshot>;

      // Group snapshots by event_id (normalized lowercase so UUID case never mismatches)
      final grouped = <String, List<PostureSnapshot>>{};
      for (final snap in snapshots) {
        final key = snap.eventId.toLowerCase();
        grouped.putIfAbsent(key, () => []).add(snap);
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _snapshotsByEvent = grouped;
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

  void _openImageViewer(PostureSnapshot snap) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(prettyLabel(snap.label)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            InteractiveViewer(
              child: Image.network(
                snap.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Could not load image'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Captured at ${_formatTime(snap.ts)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
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
            onRefresh: _loadData,
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
                              final snaps = _snapshotsByEvent[ev.eventId.toLowerCase()] ?? [];

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
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
                                      if (snaps.isNotEmpty)
                                        SizedBox(
                                          height: 92,
                                          child: ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                            scrollDirection: Axis.horizontal,
                                            itemCount: snaps.length,
                                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                                            itemBuilder: (_, sIdx) {
                                              final snap = snaps[sIdx];
                                              return GestureDetector(
                                                onTap: () => _openImageViewer(snap),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    snap.imageUrl,
                                                    width: 110,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(
                                                      width: 110,
                                                      height: 80,
                                                      color: Colors.grey.shade200,
                                                      child: const Icon(Icons.broken_image),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
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
        _loadData();
      },
    );
  }
}