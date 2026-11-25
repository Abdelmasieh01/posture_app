/// Plain Dart data models matching the Django REST & WebSocket JSON payloads.

class PostureStatus {
  final DateTime ts;
  final String label;
  final double? confidence;
  final double? distanceCm;
  final String distanceState;
  final bool postureAlert;
  final bool distanceAlert;

  PostureStatus({
    required this.ts,
    required this.label,
    required this.confidence,
    required this.distanceCm,
    required this.distanceState,
    required this.postureAlert,
    required this.distanceAlert,
  });

  factory PostureStatus.fromJson(Map<String, dynamic> json) {
    return PostureStatus(
      ts: DateTime.parse(json['ts'] as String).toLocal(),
      label: json['label'] as String? ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble(),
      distanceCm: (json['distance_cm'] as num?)?.toDouble(),
      distanceState: json['distance_state'] as String? ?? 'unknown',
      postureAlert: json['posture_alert'] as bool? ?? false,
      distanceAlert: json['distance_alert'] as bool? ?? false,
    );
  }
}

class LiveAlert {
  final String kind;
  final String label;
  final String message;
  final DateTime ts;

  LiveAlert({
    required this.kind,
    required this.label,
    required this.message,
    required this.ts,
  });

  factory LiveAlert.fromJson(Map<String, dynamic> json) {
    return LiveAlert(
      kind: json['kind'] as String? ?? 'posture',
      label: json['label'] as String? ?? '',
      message: json['message'] as String? ?? 'Bad posture detected.',
      ts: DateTime.parse(json['ts'] as String).toLocal(),
    );
  }
}

class CommandResult {
  final String command;
  final String status;
  final String detail;
  final DateTime ts;

  CommandResult({
    required this.command,
    required this.status,
    required this.detail,
    required this.ts,
  });

  factory CommandResult.fromJson(Map<String, dynamic> json) {
    return CommandResult(
      command: json['command'] as String? ?? '',
      status: json['status'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      ts: DateTime.parse(json['ts'] as String).toLocal(),
    );
  }
}

class PostureSnapshot {
  final int? id;
  final String eventId;
  final DateTime ts;
  final String label;
  final String imageUrl;

  PostureSnapshot({
    this.id,
    required this.eventId,
    required this.ts,
    required this.label,
    required this.imageUrl,
  });

  factory PostureSnapshot.fromJson(Map<String, dynamic> json) {
    return PostureSnapshot(
      id: json['id'] as int?,
      eventId: json['event_id'] as String? ?? '',
      ts: DateTime.parse(json['ts'] as String).toLocal(),
      label: json['label'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }
}

class AlertEvent {
  final String eventId;
  final DateTime ts;
  final String kind;
  final String state;
  final String label;
  final double? durationS;
  final String message;

  AlertEvent({
    required this.eventId,
    required this.ts,
    required this.kind,
    required this.state,
    required this.label,
    required this.durationS,
    required this.message,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      eventId: json['event_id'] as String,
      ts: DateTime.parse(json['ts'] as String).toLocal(),
      kind: json['kind'] as String,
      state: json['state'] as String,
      label: json['label'] as String,
      durationS: (json['duration_s'] as num?)?.toDouble(),
      message: json['message'] as String,
    );
  }
}

class SummaryBucket {
  final DateTime bucketStart;
  final double? goodPercent;
  final double? avgDistanceCm;
  final double secondsTooClose;
  final int alertCount;

  SummaryBucket({
    required this.bucketStart,
    required this.goodPercent,
    required this.avgDistanceCm,
    required this.secondsTooClose,
    required this.alertCount,
  });

  factory SummaryBucket.fromJson(Map<String, dynamic> json) {
    return SummaryBucket(
      bucketStart: DateTime.parse(json['bucket_start'] as String).toLocal(),
      goodPercent: (json['good_percent'] as num?)?.toDouble(),
      avgDistanceCm: (json['avg_distance_cm'] as num?)?.toDouble(),
      secondsTooClose: (json['seconds_too_close'] as num?)?.toDouble() ?? 0.0,
      alertCount: json['alert_count'] as int? ?? 0,
    );
  }
}

/// Helper to make backend posture labels readable in the UI.
String prettyLabel(String label) {
  switch (label) {
    case 'goodposture':
      return 'Good Posture';
    case 'forwardbadposture':
      return 'Leaning Forward';
    case 'backwardbadposture':
      return 'Leaning Backward';
    case 'headforward':
      return 'Head Forward';
    case 'tooclose':
      return 'Too Close';
    default:
      return 'Unknown';
  }
}