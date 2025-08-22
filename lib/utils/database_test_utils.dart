import '../services/database_service.dart';
import '../services/event_service.dart';
import '../models/event.dart';

class DatabaseTestUtils {
  static Future<void> testDatabaseConnection() async {
    try {
      print('🔧 데이터베이스 연결 테스트 시작');
      
      final databaseService = DatabaseService();
      final eventService = EventService();
      
      // 1. 데이터베이스 연결 테스트
      final db = await databaseService.database;
      print('✅ 데이터베이스 연결 성공');
      
      // 2. 테이블 존재 확인
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      print('📋 테이블 목록: ${tables.map((t) => t['name']).toList()}');
      
      // 3. events 테이블 구조 확인
      final eventsTableInfo = await db.rawQuery("PRAGMA table_info(events)");
      print('📊 events 테이블 구조:');
      for (final column in eventsTableInfo) {
        print('  - ${column['name']}: ${column['type']} (nullable: ${column['notnull'] == 0})');
      }
      
      // 4. 기존 이벤트 수 확인
      final eventCount = await databaseService.getEventCount();
      print('📅 기존 이벤트 수: $eventCount개');
      
      // 5. 테스트 이벤트 생성
      print('🧪 테스트 이벤트 생성 시도...');
      final testEvent = await eventService.createEvent(
        title: '테스트 이벤트',
        description: '데이터베이스 연결 테스트용 이벤트',
        startTime: DateTime.now().add(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        location: '테스트 장소',
        category: EventCategory.other,
        priority: EventPriority.medium,
      );
      print('✅ 테스트 이벤트 생성 성공: ${testEvent.id}');
      
      // 6. 생성된 이벤트 조회
      final retrievedEvent = await eventService.getEvent(testEvent.id);
      if (retrievedEvent != null) {
        print('✅ 이벤트 조회 성공: ${retrievedEvent.title}');
      } else {
        print('❌ 이벤트 조회 실패');
      }
      
      // 7. 테스트 이벤트 삭제
      final deleteResult = await eventService.deleteEvent(testEvent.id);
      print('🗑️ 테스트 이벤트 삭제: ${deleteResult ? '성공' : '실패'}');
      
      // 8. 최종 이벤트 수 확인
      final finalEventCount = await databaseService.getEventCount();
      print('📅 최종 이벤트 수: $finalEventCount개');
      
      print('🎉 데이터베이스 연결 테스트 완료!');
      
    } catch (e, stackTrace) {
      print('❌ 데이터베이스 테스트 실패: $e');
      print('📍 스택 트레이스: $stackTrace');
      rethrow;
    }
  }
  
  static Future<void> clearTestData() async {
    try {
      print('🧹 테스트 데이터 정리 시작');
      
      final databaseService = DatabaseService();
      await databaseService.clearAllTables();
      
      print('✅ 테스트 데이터 정리 완료');
    } catch (e) {
      print('❌ 테스트 데이터 정리 실패: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final databaseService = DatabaseService();
      final db = await databaseService.database;
      
      // 테이블 목록
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      
      // 각 테이블의 레코드 수
      final Map<String, int> tableCounts = {};
      for (final table in tables) {
        final tableName = table['name'] as String;
        if (!tableName.startsWith('sqlite_')) {
          final count = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
          tableCounts[tableName] = count.first['count'] as int;
        }
      }
      
      return {
        'tables': tables.map((t) => t['name']).toList(),
        'tableCounts': tableCounts,
        'databasePath': db.path,
      };
    } catch (e) {
      print('❌ 데이터베이스 정보 조회 실패: $e');
      rethrow;
    }
  }
}
