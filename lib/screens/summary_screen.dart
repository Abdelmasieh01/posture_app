import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import '../models.dart';
import '../services/api_service.dart';

/// Displays hourly (24h) or daily (7d) posture percentage bar charts from GET /api/summary/.
class SummaryScreen extends StatefulWidget {
  final String host;

  const SummaryScreen({super.key, required this.host});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  String _granularity = 'hour'; // 'hour' or 'day'
  List<SummaryBucket> _buckets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant SummaryScreen oldWidget) {
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
      final data = await ApiService(widget.host).fetchSummary(granularity: _granularity);
      if (!mounted) return;
      setState(() {
        _buckets = data;
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

  @override
  Widget build(BuildContext context) {
    final totalAlerts = _buckets.fold<int>(0, (sum, b) => sum + b.alertCount);
    final totalTooCloseMin =
        _buckets.fold<double>(0, (sum, b) => sum + b.secondsTooClose) / 60.0;
    final validDists = _buckets.where((b) => b.avgDistanceCm != null).toList();
    final meanDist = validDists.isEmpty
        ? null
        : validDists.fold<double>(0, (s, b) => s + b.avgDistanceCm!) / validDists.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'hour', label: Text('Last 24 Hours')),
              ButtonSegment(value: 'day', label: Text('Last 7 Days')),
            ],
            selected: {_granularity},
            onSelectionChanged: (s) {
              setState(() => _granularity = s.first);
              _loadData();
            },
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading summary:\n$_error'),
              ),
            )
          else ...[
            // Quick stats row
            Row(
              children: [
                _statCard('Avg Distance', meanDist != null ? '${meanDist.toStringAsFixed(1)} cm' : '--'),
                const SizedBox(width: 8),
                _statCard('Too Close', '${totalTooCloseMin.toStringAsFixed(1)} min'),
                const SizedBox(width: 8),
                _statCard('Alerts', '$totalAlerts'),
              ],
            ),
            const SizedBox(height: 16),

            // Good Posture % Bar Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Good Posture (%)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          maxY: 100,
                          minY: 0,
                          gridData: const FlGridData(show: true, horizontalInterval: 25),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 25),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= _buckets.length) return const SizedBox.shrink();
                                  // Show every 4th hour label so x-axis stays uncluttered
                                  if (_granularity == 'hour' && idx % 4 != 0) {
                                    return const SizedBox.shrink();
                                  }
                                  final dt = _buckets[idx].bucketStart;
                                  final text = _granularity == 'hour'
                                      ? '${dt.hour}h'
                                      : '${dt.month}/${dt.day}';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(text, style: const TextStyle(fontSize: 10)),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(_buckets.length, (i) {
                            final pct = _buckets[i].goodPercent ?? 0.0;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: pct,
                                  color: pct >= 70 ? Colors.teal : Colors.orange,
                                  width: _granularity == 'hour' ? 8 : 18,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}