import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite cache. Mirrors the Supabase schema closely so
/// sync logic is a straight push/pull, plus a `synced` flag on
/// rows that were created on-device and still need uploading.
class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  DBHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'attendance.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students (
            id_number TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            dept TEXT,
            year TEXT,
            synced INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            session_name TEXT NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY (session_name, date)
          )
        ''');
        await db.execute('''
          CREATE TABLE attendance_records (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_name TEXT NOT NULL,
            date TEXT NOT NULL,
            student_id TEXT NOT NULL,
            student_name TEXT,
            scanned_at TEXT NOT NULL,
            is_manual INTEGER NOT NULL DEFAULT 0,
            synced INTEGER NOT NULL DEFAULT 0,
            UNIQUE (session_name, date, student_id)
          )
        ''');
      },
    );
  }

  // ---------- Roster ----------

  Future<void> replaceRoster(List<Map<String, dynamic>> students) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('students');
    for (final s in students) {
      batch.insert('students', {...s, 'synced': 1},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> addLocalStudent(
      String id, String name, String dept, String year) async {
    final db = await database;
    await db.insert(
      'students',
      {
        'id_number': id,
        'name': name,
        'dept': dept,
        'year': year,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> lookupStudent(String idNumber) async {
    final db = await database;
    final rows =
        await db.query('students', where: 'id_number = ?', whereArgs: [idNumber]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedStudents() async {
    final db = await database;
    return db.query('students', where: 'synced = 0');
  }

  Future<void> markStudentSynced(String idNumber) async {
    final db = await database;
    await db.update('students', {'synced': 1},
        where: 'id_number = ?', whereArgs: [idNumber]);
  }

  // ---------- Sessions & attendance ----------

  Future<void> ensureSession(String sessionName, String date) async {
    final db = await database;
    await db.insert(
      'sessions',
      {
        'session_name': sessionName,
        'date': date,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> addAttendance(
      String sessionName, String date, String studentId, String studentName,
      {bool isManual = false}) async {
    final db = await database;
    return db.insert(
      'attendance_records',
      {
        'session_name': sessionName,
        'date': date,
        'student_id': studentId,
        'student_name': studentName,
        'scanned_at': DateTime.now().toIso8601String(),
        'is_manual': isManual ? 1 : 0,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> undoLastScan(String sessionName, String date) async {
    final db = await database;
    final rows = await db.query(
      'attendance_records',
      where: 'session_name = ? AND date = ?',
      whereArgs: [sessionName, date],
      orderBy: 'local_id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await db.delete('attendance_records',
          where: 'local_id = ?', whereArgs: [rows.first['local_id']]);
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAttendance() async {
    final db = await database;
    return db.query('attendance_records', where: 'synced = 0');
  }

  Future<void> markAttendanceSynced(int localId) async {
    final db = await database;
    await db.update('attendance_records', {'synced': 1},
        where: 'local_id = ?', whereArgs: [localId]);
  }

  // ---------- Session history (Notes-app style view) ----------

  /// Distinct sessions, most recent first, with a scanned-count per session.
  Future<List<Map<String, dynamic>>> getSessionHistory() async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.session_name, s.date, s.created_at,
             (SELECT COUNT(*) FROM attendance_records a
              WHERE a.session_name = s.session_name AND a.date = s.date) AS scan_count
      FROM sessions s
      ORDER BY s.date DESC, s.created_at DESC
    ''');
  }

  /// All scanned entries for one session (id, name, manual flag), for the detail view.
  Future<List<Map<String, dynamic>>> getSessionEntries(
      String sessionName, String date) async {
    final db = await database;
    return db.query(
      'attendance_records',
      where: 'session_name = ? AND date = ?',
      whereArgs: [sessionName, date],
      orderBy: 'scanned_at ASC',
    );
  }
}
