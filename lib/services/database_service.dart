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
        version: 2, // 버전 업그레이드: 알림 시간 필드 추가
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
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
        CREATE TABLE user_profiles (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
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
        CREATE TABLE events (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          startTime INTEGER NOT NULL,
          endTime INTEGER NOT NULL,
          location TEXT,
          category TEXT NOT NULL,
          priority INTEGER NOT NULL DEFAULT 2,
          isAllDay INTEGER NOT NULL DEFAULT 0,
          recurrenceRule TEXT,
          attendees TEXT,
          color TEXT NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          alarmMinutesBefore INTEGER NOT NULL DEFAULT 10,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      ''');
      print('✅ events 테이블 생성 완료');

      // 채팅 세션 테이블
      print('💬 chat_sessions 테이블 생성 중...');
      await db.execute('''
        CREATE TABLE chat_sessions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          lastMessageAt INTEGER NOT NULL,
          messageCount INTEGER NOT NULL DEFAULT 0,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
      print('✅ chat_sessions 테이블 생성 완료');

      // 채팅 메시지 테이블
      print('📝 chat_messages 테이블 생성 중...');
      await db.execute('''
        CREATE TABLE chat_messages (
          id TEXT PRIMARY KEY,
          sessionId TEXT NOT NULL,
          content TEXT NOT NULL,
          type TEXT NOT NULL,
          sender TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          metadata TEXT,
          parentMessageId TEXT,
          attachments TEXT,
          status TEXT NOT NULL,
          FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE
        )
      ''');
      print('✅ chat_messages 테이블 생성 완료');

      // 인덱스 생성
      print('📊 인덱스 생성 중...');
      await db.execute('CREATE INDEX idx_events_start_time ON events(startTime)');
      await db.execute('CREATE INDEX idx_events_category ON events(category)');
      await db.execute('CREATE INDEX idx_chat_messages_session ON chat_messages(sessionId)');
      await db.execute('CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp)');
      print('✅ 모든 인덱스 생성 완료');
      
      print('🎉 데이터베이스 테이블 생성 모두 완료!');
    } catch (e, stackTrace) {
      print('❌ 테이블 생성 실패: $e');
      print('📍 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    print('🔄 데이터베이스 업그레이드: $oldVersion → $newVersion');
    
    if (oldVersion < 2) {
      // 버전 2: alarmMinutesBefore 필드 추가
      print('📅 events 테이블에 alarmMinutesBefore 컬럼 추가 중...');
      await db.execute('ALTER TABLE events ADD COLUMN alarmMinutesBefore INTEGER NOT NULL DEFAULT 10');
      print('✅ alarmMinutesBefore 컬럼 추가 완료');
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
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.insert('user_profiles', profile.toMap());
  }

  Future<UserProfile?> getUserProfile(String id) async {
    final db = await database;
    final maps = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
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

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.update(
      'user_profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> deleteUserProfile(String id) async {
    final db = await database;
    return await db.delete(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 일정 CRUD
  Future<int> insertEvent(Event event) async {
    try {
      print('🗄️ DatabaseService: 이벤트 삽입 시작');
      print('📋 이벤트 데이터: ${event.toMap()}');
      
      final db = await database;
      print('✅ 데이터베이스 연결 성공');
      
      final result = await db.insert('events', event.toMap());
      print('💾 이벤트 삽입 성공: result = $result');
      
      // 삽입 후 검증
      final inserted = await db.query('events', where: 'id = ?', whereArgs: [event.id]);
      print('🔍 삽입된 데이터 검증: ${inserted.length}개 발견');
      
      return result;
    } catch (e, stackTrace) {
      print('❌ DatabaseService.insertEvent 실패: $e');
      print('📍 스택 트레이스: $stackTrace');
      
      // 데이터베이스 테이블 상태 확인
      try {
        final db = await database;
        final tableInfo = await db.rawQuery("PRAGMA table_info(events)");
        print('📊 events 테이블 구조: $tableInfo');
      } catch (tableError) {
        print('⚠️ 테이블 정보 조회 실패: $tableError');
      }
      
      rethrow;
    }
  }

  Future<Event?> getEvent(String id) async {
    final db = await database;
    final maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return Event.fromMap(maps.first);
    }
    return null;
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
    
    if (category != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'category = ?';
      whereArgs.add(category);
    }
    
    if (priority != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'priority = ?';
      whereArgs.add(priority);
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

  Future<List<Event>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return await getEvents(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  Future<int> updateEvent(Event event) async {
    final db = await database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(String id) async {
    final db = await database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 채팅 세션 CRUD
  Future<int> insertChatSession(ChatSession session) async {
    final db = await database;
    return await db.insert('chat_sessions', session.toMap());
  }

  Future<ChatSession?> getChatSession(String id) async {
    final db = await database;
    final maps = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return ChatSession.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ChatSession>> getChatSessions() async {
    final db = await database;
    final maps = await db.query(
      'chat_sessions',
      orderBy: 'lastMessageAt DESC',
    );
    
    return maps.map((map) => ChatSession.fromMap(map)).toList();
  }

  Future<int> updateChatSession(ChatSession session) async {
    final db = await database;
    return await db.update(
      'chat_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> deleteChatSession(String id) async {
    final db = await database;
    return await db.delete(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 채팅 메시지 CRUD
  Future<int> insertChatMessage(ChatMessage message, String sessionId) async {
    final db = await database;
    final messageMap = message.toMap();
    messageMap['sessionId'] = sessionId;
    return await db.insert('chat_messages', messageMap);
  }

  Future<List<ChatMessage>> getChatMessages(String sessionId, {int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'chat_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  Future<int> updateChatMessage(ChatMessage message) async {
    final db = await database;
    return await db.update(
      'chat_messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<int> deleteChatMessage(String id) async {
    final db = await database;
    return await db.delete(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
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