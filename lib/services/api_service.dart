import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

/// Thin REST client for the Django monitor endpoints.
class ApiService {
  final String host; // e.g. "192.168.1.10:8000" or "localhost:8000"

  ApiService(this.host);

  String get _cleanHost =>
      host.trim().replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/$'), '');

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.http(_cleanHost, path, query);

  /// GET /api/health/ -> returns true if backend responds with {"ok": true}
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(_uri('/api/health/')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['ok'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/events/?limit=50&kind=...
  Future<List<AlertEvent>> fetchEvents({String? kind, int limit = 50}) async {
    final query = <String, String>{'limit': '$limit'};
    if (kind != null && kind.isNotEmpty) {
      query['kind'] = kind;
    }
    final res = await http.get(_uri('/api/events/', query)).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Failed to load events (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AlertEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/summary/?granularity=hour|day
  Future<List<SummaryBucket>> fetchSummary({required String granularity}) async {
    final res = await http
        .get(_uri('/api/summary/', {'granularity': granularity}))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Failed to load summary (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => SummaryBucket.fromJson(e as Map<String, dynamic>)).toList();
  }
}