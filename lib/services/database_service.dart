import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/recording.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'voice_recorder.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recordings(
            id TEXT PRIMARY KEY,
            startTime TEXT NOT NULL,
            endTime TEXT,
            durationSeconds INTEGER NOT NULL,
            localPath TEXT NOT NULL,
            audioPath TEXT,
            status TEXT NOT NULL,
            geminiModel TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            fileSizeBytes INTEGER NOT NULL,
            transcriptText TEXT,
            error TEXT,
            createdAt TEXT NOT NULL,
            transcribedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE upload_queue(
            id TEXT PRIMARY KEY,
            recordingId TEXT NOT NULL,
            attempts INTEGER DEFAULT 0,
            lastAttempt TEXT,
            FOREIGN KEY (recordingId) REFERENCES recordings(id)
          )
        ''');
      },
    );
  }

  // Recording CRUD operations
  Future<void> insertRecording(Recording recording) async {
    final db = await database;
    await db.insert(
      'recordings',
      recording.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRecording(Recording recording) async {
    final db = await database;
    await db.update(
      'recordings',
      recording.toMap(),
      where: 'id = ?',
      whereArgs: [recording.id],
    );
  }

  Future<Recording?> getRecording(String id) async {
    final db = await database;
    final maps = await db.query(
      'recordings',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Recording.fromMap(maps.first);
  }

  Future<List<Recording>> getAllRecordings() async {
    final db = await database;
    final maps = await db.query(
      'recordings',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Recording.fromMap(m)).toList();
  }

  Future<List<Recording>> getPendingUploads() async {
    final db = await database;
    final maps = await db.query(
      'recordings',
      where: 'status = ?',
      whereArgs: [RecordingStatus.pending.name],
      orderBy: 'createdAt ASC',
    );
    return maps.map((m) => Recording.fromMap(m)).toList();
  }

  /// Get upload attempt information for a recording
  Future<Map<String, dynamic>?> getUploadAttempts(String recordingId) async {
    final db = await database;
    final maps = await db.query(
      'upload_queue',
      where: 'recordingId = ?',
      whereArgs: [recordingId],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> deleteRecording(String id) async {
    final db = await database;
    await db.delete(
      'recordings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Replace local ID with server ID after successful upload
  Future<void> replaceRecordingId(String oldId, Recording updatedRecording) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete old record
      await txn.delete(
        'recordings',
        where: 'id = ?',
        whereArgs: [oldId],
      );
      // Insert with new ID
      await txn.insert(
        'recordings',
        updatedRecording.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // Upload queue operations
  Future<void> addToUploadQueue(String recordingId) async {
    final db = await database;
    await db.insert(
      'upload_queue',
      {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'recordingId': recordingId,
        'attempts': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFromUploadQueue(String recordingId) async {
    final db = await database;
    await db.delete(
      'upload_queue',
      where: 'recordingId = ?',
      whereArgs: [recordingId],
    );
  }

  Future<void> incrementUploadAttempts(String recordingId) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE upload_queue
      SET attempts = attempts + 1, lastAttempt = ?
      WHERE recordingId = ?
    ''', [DateTime.now().toIso8601String(), recordingId]);
  }
}
