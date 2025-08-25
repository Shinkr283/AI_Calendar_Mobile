import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import '../models/event.dart' as local;
import '../services/event_service.dart';
import '../services/simple_google_sign_in_service.dart';

/// SimpleGoogleSignInService와 호환되는 캘린더 동기화 서비스
class SimpleGoogleCalendarService {
  static final SimpleGoogleCalendarService _instance = SimpleGoogleCalendarService._internal();
  factory SimpleGoogleCalendarService() => _instance;
  SimpleGoogleCalendarService._internal();

  /// Google 계정에서 액세스 토큰을 가져와서 캘린더 동기화
  Future<int> syncFromGoogleCalendar() async {
    try {
      print('📅 구글 캘린더 동기화 시작');
      
      // 1. 현재 로그인된 Google 계정 확인
      final googleUser = SimpleGoogleSignInService().currentUser;
      if (googleUser == null) {
        throw Exception('Google 계정에 로그인되어 있지 않습니다.');
      }
      
      // 2. 인증 정보 가져오기
      final GoogleSignInAuthentication auth = await googleUser.authentication;
      if (auth.accessToken == null) {
        throw Exception('Google 액세스 토큰을 가져올 수 없습니다.');
      }
      
      print('✅ Google 액세스 토큰 획득: ${auth.accessToken!.substring(0, 20)}...');
      
      // 3. Google Calendar API 클라이언트 생성
      final client = GoogleAuthClient(auth.accessToken!);
      final calendarApi = calendar.CalendarApi(client);
      
      // 4. 이번 달의 이벤트 가져오기
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      print('📅 기간: ${startOfMonth.toString()} ~ ${endOfMonth.toString()}');
      
      final events = await calendarApi.events.list(
        'primary',
        timeMin: startOfMonth.toUtc(),
        timeMax: endOfMonth.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 100,
      );
      
      final googleEvents = events.items ?? [];
      print('📥 구글 캘린더에서 ${googleEvents.length}개 이벤트 가져옴');
      
      // 5. Local 이벤트로 변환하고 데이터베이스에 저장
      int syncedCount = 0;
      final eventService = EventService();
      
      for (final googleEvent in googleEvents) {
        try {
          final localEvent = _convertGoogleEventToLocal(googleEvent);
          if (localEvent != null) {
            // 중복 확인 (Google Event ID로)
            final existingEvents = await eventService.getEventsForDate(localEvent.startTime);
            final isDuplicate = existingEvents.any((e) => 
              e.googleEventId == googleEvent.id ||
              (e.title == localEvent.title && 
               e.startTime.isAtSameMomentAs(localEvent.startTime))
            );
            
            if (!isDuplicate) {
                             // EventService의 createEvent 메서드 사용
               await eventService.createEvent(
                 title: localEvent.title,
                 description: localEvent.description,
                 startTime: localEvent.startTime,
                 endTime: localEvent.endTime,
                 alarmMinutesBefore: localEvent.alarmMinutesBefore,
                 location: localEvent.location,
                 isAllDay: localEvent.isAllDay,
               );
              syncedCount++;
              print('➕ 동기화: ${localEvent.title}');
            } else {
              print('⏭️ 중복 건너뜀: ${localEvent.title}');
            }
          }
        } catch (e) {
          print('⚠️ 이벤트 변환 실패: ${googleEvent.summary ?? 'Unknown'} - $e');
        }
      }
      
      print('🎉 구글 캘린더 동기화 완료: ${syncedCount}개 이벤트 추가');
      return syncedCount;
      
    } catch (e, stackTrace) {
      print('❌ 구글 캘린더 동기화 실패: $e');
      print('📊 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  /// 우리 앱의 일정을 Google Calendar로 내보내기
  Future<int> exportToGoogleCalendar() async {
    try {
      print('📤 구글 캘린더로 일정 내보내기 시작');
      
      // 1. 현재 로그인된 Google 계정 확인
      final googleUser = SimpleGoogleSignInService().currentUser;
      if (googleUser == null) {
        throw Exception('Google 계정에 로그인되어 있지 않습니다.');
      }
      
      // 2. 인증 정보 가져오기
      final GoogleSignInAuthentication auth = await googleUser.authentication;
      if (auth.accessToken == null) {
        throw Exception('Google 액세스 토큰을 가져올 수 없습니다.');
      }
      
      print('✅ Google 액세스 토큰 획득: ${auth.accessToken!.substring(0, 20)}...');
      
      // 3. Google Calendar API 클라이언트 생성
      final client = GoogleAuthClient(auth.accessToken!);
      final calendarApi = calendar.CalendarApi(client);
      
      // 4. 우리 앱의 일정 가져오기 (이번 달)
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      final eventService = EventService();
      final localEvents = await eventService.getEventsForDateRange(startOfMonth, endOfMonth);
      
      print('📥 우리 앱에서 ${localEvents.length}개 이벤트 가져옴');
      
      // 5. Google Calendar로 내보내기
      int exportedCount = 0;
      
      for (final localEvent in localEvents) {
        try {
          // 이미 Google Calendar에 있는지 확인 (googleEventId로)
          if (localEvent.googleEventId != null && localEvent.googleEventId!.isNotEmpty) {
            print('⏭️ 이미 Google Calendar에 있음: ${localEvent.title}');
            continue;
          }
          
          // Google Calendar 이벤트로 변환
          final googleEvent = _convertLocalEventToGoogle(localEvent);
          
          // Google Calendar에 추가
          final createdEvent = await calendarApi.events.insert(googleEvent, 'primary');
          
                     // 로컬 이벤트에 Google Event ID 저장
           await eventService.updateEventWithGoogleId(
             localEvent.id,
             googleEventId: createdEvent.id,
           );
          
          exportedCount++;
          print('📤 내보내기 완료: ${localEvent.title}');
          
        } catch (e) {
          print('⚠️ 이벤트 내보내기 실패: ${localEvent.title} - $e');
        }
      }
      
      print('🎉 구글 캘린더로 내보내기 완료: ${exportedCount}개 이벤트 추가');
      return exportedCount;
      
    } catch (e, stackTrace) {
      print('❌ 구글 캘린더로 내보내기 실패: $e');
      print('📊 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  /// Google Calendar Event를 Local Event로 변환
  local.Event? _convertGoogleEventToLocal(calendar.Event googleEvent) {
    try {
      // 제목이 없는 이벤트는 건너뜀
      if (googleEvent.summary == null || googleEvent.summary!.isEmpty) {
        return null;
      }
      
      // 시작 시간 파싱
      DateTime? startTime;
      if (googleEvent.start?.dateTime != null) {
        startTime = googleEvent.start!.dateTime!.toLocal();
      } else if (googleEvent.start?.date != null) {
        startTime = googleEvent.start!.date!.toLocal();
      } else {
        print('⚠️ 시작 시간이 없는 이벤트: ${googleEvent.summary}');
        return null;
      }
      
      // 종료 시간 파싱
      DateTime? endTime;
      if (googleEvent.end?.dateTime != null) {
        endTime = googleEvent.end!.dateTime!.toLocal();
      } else if (googleEvent.end?.date != null) {
        endTime = googleEvent.end!.date!.toLocal();
      } else {
        // 종료 시간이 없으면 시작 시간 + 1시간
        endTime = startTime.add(const Duration(hours: 1));
      }
      
      // 하루 종일 이벤트 확인
      final isAllDay = googleEvent.start?.date != null;
      
             return local.Event(
         id: googleEvent.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
         title: googleEvent.summary!,
         description: googleEvent.description ?? '',
         startTime: startTime,
         endTime: endTime,
         location: googleEvent.location ?? '',
         locationLatitude: null, // Google Calendar에서 좌표 정보가 있다면 파싱 가능
         locationLongitude: null,
         googleEventId: googleEvent.id, // 중복 확인용
         isCompleted: false,
         isAllDay: isAllDay,
         alarmMinutesBefore: 0, // 기본값 0분 (알림 없음)
         createdAt: DateTime.now(),
         updatedAt: DateTime.now(),
       );
      
    } catch (e) {
      print('⚠️ 이벤트 변환 오류: $e');
      return null;
    }
  }

  /// Local Event를 Google Calendar Event로 변환
  calendar.Event _convertLocalEventToGoogle(local.Event localEvent) {
    // 시작 시간 설정
    calendar.EventDateTime startDateTime;
    if (localEvent.isAllDay) {
      startDateTime = calendar.EventDateTime(
        date: localEvent.startTime.toUtc(),
        timeZone: 'Asia/Seoul',
      );
    } else {
      startDateTime = calendar.EventDateTime(
        dateTime: localEvent.startTime.toUtc(),
        timeZone: 'Asia/Seoul',
      );
    }
    
    // 종료 시간 설정
    calendar.EventDateTime endDateTime;
    if (localEvent.isAllDay) {
      endDateTime = calendar.EventDateTime(
        date: localEvent.endTime.toUtc(),
        timeZone: 'Asia/Seoul',
      );
    } else {
      endDateTime = calendar.EventDateTime(
        dateTime: localEvent.endTime.toUtc(),
        timeZone: 'Asia/Seoul',
      );
    }
    
    return calendar.Event(
      summary: localEvent.title,
      description: localEvent.description.isNotEmpty ? localEvent.description : null,
      location: localEvent.location.isNotEmpty ? localEvent.location : null,
      start: startDateTime,
      end: endDateTime,
      reminders: localEvent.alarmMinutesBefore > 0 
        ? calendar.EventReminders(
            useDefault: false,
            overrides: [
              calendar.EventReminder(
                method: 'popup',
                minutes: localEvent.alarmMinutesBefore,
              ),
            ],
          )
        : null,
    );
  }
}

/// Google API 인증을 위한 HTTP 클라이언트
class GoogleAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner = http.Client();

  GoogleAuthClient(this.accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['Content-Type'] = 'application/json';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
