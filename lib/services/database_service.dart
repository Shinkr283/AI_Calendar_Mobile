import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/event.dart';
import '../models/user_profile.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  
  factory DatabaseService() => _instance;
  
  DatabaseService._internal();

  /// DB 연결 후 작업 실행, 항상 연결 해제
  Future<T> _withDb<T>(Future<T> Function(Database db) action) async {
    final db = await database;
    try {
      return await action(db);
    } finally {
      await db.close();
      _database = null;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      print('🔧 DatabaseService: 데이터베이스 초기화 시작');
      
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'ai_calendar.db');
      print('📁 데이터베이스 경로: $path');

             final db = await openDatabase(
         path,
         version: 1,
         onCreate: _createDatabase,
       );
      
      print('✅ 데이터베이스 초기화 완료');
      
      // 테이블 존재 확인
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      print('📋 존재하는 테이블들: ${tables.map((t) => t['name']).toList()}');
      
      return db;
    } catch (e, stackTrace) {
      print('❌ 데이터베이스 초기화 실패: $e');
      print('📍 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    try {
      print('🏗️ 데이터베이스 테이블 생성 시작');
      
      // 사용자 프로필 테이블
      print('👤 user_profiles 테이블 생성 중...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profiles (
          email TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          profileImageUrl TEXT,
          phoneNumber TEXT,
          mbtiType TEXT,
          preferences TEXT,
          timezone TEXT NOT NULL,
          language TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      ''');
      print('✅ user_profiles 테이블 생성 완료');

      // 일정 테이블
      print('📅 events 테이블 생성 중...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS events (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          startTime INTEGER NOT NULL,
          endTime INTEGER NOT NULL,
          location TEXT,
          locationLatitude REAL,
          locationLongitude REAL,
          priority INTEGER NOT NULL DEFAULT 0,
          googleEventId TEXT UNIQUE,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          isAllDay INTEGER NOT NULL DEFAULT 0,
          alarmMinutesBefore INTEGER NOT NULL DEFAULT 10,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      ''');
      print('✅ events 테이블 생성 완료');

      // 채팅 세션 테이블
      print('💬 chat_sessions 테이블 생성 중...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_sessions (
          id TEXT PRIMARY KEY,
          userEmail TEXT NOT NULL,
          title TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          lastMessageAt INTEGER NOT NULL,
          messageCount INTEGER NOT NULL DEFAULT 0,
          isActive INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (userEmail) REFERENCES user_profiles (email) ON DELETE CASCADE
        )
      ''');
      print('✅ chat_sessions 테이블 생성 완료');

      // 채팅 메시지 테이블
      print('📝 chat_messages 테이블 생성 중...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
          id TEXT PRIMARY KEY,
          sessionId TEXT NOT NULL,
          userEmail TEXT NOT NULL,
          content TEXT NOT NULL,
          type TEXT NOT NULL,
          sender TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          metadata TEXT,
          parentMessageId TEXT,
          attachments TEXT,
          status TEXT NOT NULL,
          FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE,
          FOREIGN KEY (userEmail) REFERENCES user_profiles (email) ON DELETE CASCADE
        )
      ''');
      print('✅ chat_messages 테이블 생성 완료');

      // 인덱스 생성
      print('📊 인덱스 생성 중...');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(startTime)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_updated_at ON events(updatedAt)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(sessionId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp)');
      print('✅ 모든 인덱스 생성 완료');
      
      print('🎉 데이터베이스 테이블 생성 모두 완료!');
    } catch (e, stackTrace) {
      print('❌ 테이블 생성 실패: $e');
      print('📍 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 데이터베이스 닫기
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // 모든 테이블 초기화 (개발용)
  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('chat_messages');
      await txn.delete('chat_sessions');
      await txn.delete('events');
      await txn.delete('user_profiles');
    });
  }

  // 사용자 프로필 CRUD
  Future<int> insertUserProfile(UserProfile profile) {
    return _withDb<int>((db) => db.insert('user_profiles', profile.toMap()));
  }

  Future<UserProfile?> getUserProfile(String id) {
    return _withDb<UserProfile?>((db) async {
      final maps = await db.query('user_profiles', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) return UserProfile.fromMap(maps.first);
      return null;
    });
  }

  Future<UserProfile?> getUserProfileByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'user_profiles',
      where: 'email = ?',
      whereArgs: [email],
    );
    
    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<UserProfile?> getFirstUserProfile() async {
    final db = await database;
    final maps = await db.query(
      'user_profiles',
      limit: 1,
      orderBy: 'createdAt ASC',
    );

    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUserProfile(UserProfile profile) {
    return _withDb<int>((db) async {
      // 기존 데이터 조회 및 비교 로직
      final maps = await db.query('user_profiles', where: 'email = ?', whereArgs: [profile.email]);
      if (maps.isEmpty) return db.insert('user_profiles', profile.toMap());
      final existing = maps.first;
      final existingUpdatedAt = DateTime.fromMillisecondsSinceEpoch(existing['updatedAt'] as int);
      final existingCreatedAt = DateTime.fromMillisecondsSinceEpoch(existing['createdAt'] as int);
      if (profile.updatedAt.isAfter(existingUpdatedAt) || profile.createdAt.isAfter(existingCreatedAt)) {
        return db.update('user_profiles', profile.toMap(), where: 'email = ?', whereArgs: [profile.email]);
      }
      return 0;
    });
  }

  Future<int> deleteUserProfile(String email) {
    return _withDb<int>((db) => db.delete('user_profiles', where: 'email = ?', whereArgs: [email]));
  }

  // 일정 CRUD
  Future<int> insertEvent(Event event) {
    return _withDb<int>((db) => db.insert('events', event.toMap()));
  }

  Future<Event?> getEvent(String id) {
    return _withDb<Event?>((db) async {
      final maps = await db.query('events', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) return Event.fromMap(maps.first);
      return null;
    });
  }

  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    int? priority,
    bool? isCompleted,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause += 'startTime >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'endTime <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }
      
    if (isCompleted != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'isCompleted = ?';
      whereArgs.add(isCompleted ? 1 : 0);
    }
    
    final maps = await db.query(
      'events',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'startTime ASC',
    );
    
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  Future<Event?> getEventByGoogleId(String googleEventId) async {
    final db = await database;
    final maps = await db.query(
      'events',
      where: 'googleEventId = ?',
      whereArgs: [googleEventId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Event.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Event>> getEventsForDate(DateTime date) async {
  
    // 하루와 "겹치는" 모든 일정 반환: (endTime >= startOfDay) AND (startTime <= endOfDay)
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;

    final maps = await db.query(
      'events',
      where: 'endTime >= ? AND startTime <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'startTime ASC',
    );

    return maps.map((map) => Event.fromMap(map)).toList();
  }

  Future<int> getLatestEventUpdatedAtForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT MAX(updatedAt) as maxUpdated FROM events WHERE endTime >= ? AND startTime <= ?',
      [startOfDay, endOfDay],
    );
    if (result.isNotEmpty) {
      final value = result.first['maxUpdated'];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return 0;
  }

  Future<int> updateEvent(Event event) {
    return _withDb<int>((db) async {
      // 기존 데이터 조회 및 비교
      final maps = await db.query('events', where: 'id = ?', whereArgs: [event.id]);
      if (maps.isEmpty) return db.insert('events', event.toMap());
      final existing = maps.first;
      final existingUpdatedAt = DateTime.fromMillisecondsSinceEpoch(existing['updatedAt'] as int);
      final existingCreatedAt = DateTime.fromMillisecondsSinceEpoch(existing['createdAt'] as int);
      final existingGoogleId = existing['googleEventId'] as String?;
      if (event.googleEventId != null && (existingGoogleId == null || existingGoogleId.isEmpty)) {
        return db.update('events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
      }
      if (event.updatedAt.isAfter(existingUpdatedAt) || event.createdAt.isAfter(existingCreatedAt)) {
        return db.update('events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
      }
      return 0;
    });
  }

  // 대량 업데이트(배치)
  Future<int> bulkUpdateEvents(List<Event> events) {
    if (events.isEmpty) return Future.value(0);
    return _withDb<int>((db) async {
      final batch = db.batch();
      for (final e in events) {
        batch.update(
          'events',
          e.toMap(),
          where: 'id = ?',
          whereArgs: [e.id],
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final results = await batch.commit(noResult: false, continueOnError: true);
      return results.length;
    });
  }

  Future<int> deleteEvent(String id) {
    return _withDb<int>((db) => db.delete('events', where: 'id = ?', whereArgs: [id]));
  }

  // 채팅 세션 CRUD
  Future<int> insertChatSession(ChatSession session) {
    return _withDb<int>((db) => db.insert('chat_sessions', session.toMap()));
  }

  Future<ChatSession?> getChatSession(String id) {
    return _withDb<ChatSession?>((db) async {
      final maps = await db.query('chat_sessions', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) return ChatSession.fromMap(maps.first);
      return null;
    });
  }

  Future<List<ChatSession>> getChatSessions() async {
    final db = await database;
    final maps = await db.query(
      'chat_sessions',
      orderBy: 'lastMessageAt DESC',
    );
    
    return maps.map((map) => ChatSession.fromMap(map)).toList();
  }

  Future<int> updateChatSession(ChatSession session) {
    return _withDb<int>((db) => db.update('chat_sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]));
  }

  Future<int> deleteChatSession(String id) {
    return _withDb<int>((db) => db.delete('chat_sessions', where: 'id = ?', whereArgs: [id]));
  }

  // 채팅 메시지 CRUD
  Future<int> insertChatMessage(ChatMessage message, String sessionId) {
    return _withDb<int>((db) {
      final map = message.toMap()..['sessionId'] = sessionId;
      return db.insert('chat_messages', map);
    });
  }

  Future<List<ChatMessage>> getChatMessages(String sessionId, {int? limit}) {
    return _withDb<List<ChatMessage>>((db) async {
      final maps = await db.query('chat_messages', where: 'sessionId = ?', whereArgs: [sessionId], orderBy: 'timestamp DESC', limit: limit);
      return maps.map((m) => ChatMessage.fromMap(m)).toList();
    });
  }

  Future<int> updateChatMessage(ChatMessage message) {
    return _withDb<int>((db) => db.update('chat_messages', message.toMap(), where: 'id = ?', whereArgs: [message.id]));
  }

  Future<int> deleteChatMessage(String id) {
    return _withDb<int>((db) => db.delete('chat_messages', where: 'id = ?', whereArgs: [id]));
  }

  // 통계 및 유틸리티 메서드
  Future<int> getEventCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM events');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getChatMessageCount(String sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chat_messages WHERE sessionId = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Event>> searchEvents(String query) async {
    final db = await database;
    final maps = await db.query(
      'events',
      where: 'title LIKE ? OR description LIKE ? OR location LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'startTime ASC',
    );
    
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  Future<List<ChatMessage>> searchChatMessages(String query) async {
    final db = await database;
    final maps = await db.query(
      'chat_messages',
      where: 'content LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }
} 