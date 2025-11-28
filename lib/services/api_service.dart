import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/recording.dart';

class ApiService extends ChangeNotifier {
  String? _apiKey;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    notifyListeners();
  }

  String? get apiKey => _apiKey;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey != null) 'X-API-Key': _apiKey!,
  };

  // Get upload URL for new recording
  Future<UploadUrlResponse> getUploadUrl({
    required DateTime startTime,
    required int durationSeconds,
    double? latitude,
    double? longitude,
    String geminiModel = 'flash',
    int fileSizeBytes = 0,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/recordings/upload-url'),
      headers: _headers,
      body: jsonEncode({
        'startTime': startTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'geminiModel': geminiModel,
        'fileSizeBytes': fileSizeBytes,
        if (latitude != null && longitude != null)
          'location': {'lat': latitude, 'lng': longitude},
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to get upload URL: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return UploadUrlResponse(
      id: data['id'],
      uploadUrl: data['uploadUrl'],
      audioPath: data['audioPath'],
    );
  }

  // Upload audio file to signed URL
  Future<void> uploadAudioFile(String uploadUrl, File file) async {
    final bytes = await file.readAsBytes();

    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'audio/mp4'},
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to upload audio: ${response.statusCode}');
    }
  }

  // Mark upload complete and start transcription
  Future<void> completeUpload(String recordingId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/recordings/$recordingId/complete-upload'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to complete upload: ${response.body}');
    }
  }

  // Get recording status
  Future<ApiRecording?> getRecording(String id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/recordings/$id'),
      headers: _headers,
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException('Failed to get recording: ${response.body}');
    }

    return ApiRecording.fromJson(jsonDecode(response.body));
  }

  // List recordings
  Future<List<ApiRecording>> listRecordings({int limit = 20, String? startAfter}) async {
    var url = '${AppConfig.apiBaseUrl}/recordings?limit=$limit';
    if (startAfter != null) {
      url += '&startAfter=$startAfter';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to list recordings: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['recordings'] as List)
        .map((r) => ApiRecording.fromJson(r))
        .toList();
  }

  // Search recordings
  Future<List<ApiRecording>> searchRecordings({
    String? query,
    DateTime? from,
    DateTime? to,
    int limit = 20,
  }) async {
    final params = <String, String>{};
    if (query != null) params['q'] = query;
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    params['limit'] = limit.toString();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/search')
        .replace(queryParameters: params);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw ApiException('Search failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['results'] as List)
        .map((r) => ApiRecording.fromJson(r))
        .toList();
  }

  // Retry failed transcription
  Future<void> retryTranscription(String recordingId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/recordings/$recordingId/retry'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to retry: ${response.body}');
    }
  }

  // Get signed audio URL
  Future<String> getAudioUrl(String recordingId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/recordings/$recordingId/audio'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to get audio URL: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['url'];
  }
}

class UploadUrlResponse {
  final String id;
  final String uploadUrl;
  final String audioPath;

  UploadUrlResponse({
    required this.id,
    required this.uploadUrl,
    required this.audioPath,
  });
}

class ApiRecording {
  final String id;
  final String status;
  final String? transcriptText;
  final DateTime createdAt;
  final DateTime? transcribedAt;
  final String? error;

  ApiRecording({
    required this.id,
    required this.status,
    this.transcriptText,
    required this.createdAt,
    this.transcribedAt,
    this.error,
  });

  factory ApiRecording.fromJson(Map<String, dynamic> json) {
    return ApiRecording(
      id: json['id'],
      status: json['status'],
      transcriptText: json['transcript']?['text'],
      createdAt: DateTime.parse(json['createdAt']),
      transcribedAt: json['transcribedAt'] != null
          ? DateTime.parse(json['transcribedAt'])
          : null,
      error: json['error'],
    );
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
