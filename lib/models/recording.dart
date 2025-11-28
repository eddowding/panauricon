class Recording {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String localPath;
  final String? audioPath;
  final RecordingStatus status;
  final String geminiModel;
  final double? latitude;
  final double? longitude;
  final int fileSizeBytes;
  final String? transcriptText;
  final String? error;
  final DateTime createdAt;
  final DateTime? transcribedAt;

  Recording({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.localPath,
    this.audioPath,
    required this.status,
    required this.geminiModel,
    this.latitude,
    this.longitude,
    required this.fileSizeBytes,
    this.transcriptText,
    this.error,
    required this.createdAt,
    this.transcribedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'localPath': localPath,
    'audioPath': audioPath,
    'status': status.name,
    'geminiModel': geminiModel,
    'latitude': latitude,
    'longitude': longitude,
    'fileSizeBytes': fileSizeBytes,
    'transcriptText': transcriptText,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
    'transcribedAt': transcribedAt?.toIso8601String(),
  };

  factory Recording.fromMap(Map<String, dynamic> map) => Recording(
    id: map['id'],
    startTime: DateTime.parse(map['startTime']),
    endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
    durationSeconds: map['durationSeconds'],
    localPath: map['localPath'],
    audioPath: map['audioPath'],
    status: RecordingStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => RecordingStatus.pending,
    ),
    geminiModel: map['geminiModel'] ?? 'flash',
    latitude: map['latitude'],
    longitude: map['longitude'],
    fileSizeBytes: map['fileSizeBytes'] ?? 0,
    transcriptText: map['transcriptText'],
    error: map['error'],
    createdAt: DateTime.parse(map['createdAt']),
    transcribedAt: map['transcribedAt'] != null
        ? DateTime.parse(map['transcribedAt'])
        : null,
  );

  Recording copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? localPath,
    String? audioPath,
    RecordingStatus? status,
    String? geminiModel,
    double? latitude,
    double? longitude,
    int? fileSizeBytes,
    String? transcriptText,
    String? error,
    DateTime? createdAt,
    DateTime? transcribedAt,
  }) {
    return Recording(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      localPath: localPath ?? this.localPath,
      audioPath: audioPath ?? this.audioPath,
      status: status ?? this.status,
      geminiModel: geminiModel ?? this.geminiModel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      transcriptText: transcriptText ?? this.transcriptText,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      transcribedAt: transcribedAt ?? this.transcribedAt,
    );
  }
}

enum RecordingStatus {
  recording,
  pending,      // Saved locally, waiting to upload
  uploading,
  uploaded,
  transcribing,
  transcribed,
  failed,
}
