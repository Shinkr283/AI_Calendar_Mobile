import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_calendar_service.dart';
import '../services/event_service.dart';
import '../models/event.dart';

class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  factory CalendarSyncService() => _instance;
  CalendarSyncService._internal();

  Future<String?> _ensureAccessToken({bool readonly = true}) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('google_access_token');
    if (token != null && token.isNotEmpty) return token;

    final scopes = <String>[
      'email',
      readonly
          ? 'https://www.googleapis.com/auth/calendar.readonly'
          : 'https://www.googleapis.com/auth/calendar',
    ];

    final google = GoogleSignIn(scopes: scopes);
    var account = await google.signInSilently();
    account ??= await google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    token = auth.accessToken;
    if (token != null && token.isNotEmpty) {
      await prefs.setString('google_access_token', token);
    }
    return token;
  }

  Future<int> syncCurrentMonth({bool readonly = true}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return syncRange(start: start, end: end, readonly: readonly);
  }

  Future<int> syncRange({
    required DateTime start,
    required DateTime end,
    bool readonly = true,
  }) async {
    final token = await _ensureAccessToken(readonly: readonly);
    if (token == null || token.isEmpty) {
      throw Exception('구글 로그인이 필요합니다.');
    }

    final svc = GoogleCalendarService(token);
    final items = await svc.fetchEventsInRange(
      timeMin: start,
      timeMax: end,
      singleEvents: true,
      orderBy: 'startTime',
      timeZone: 'Asia/Seoul',
    );

    final prefs = await SharedPreferences.getInstance();
    final syncedIds = prefs.getStringList('google_synced_event_ids')?.toSet() ?? <String>{};

    var inserted = 0;
    for (final ev in items) {
      final startTime = ev.start?.dateTime ?? ev.start?.date?.toLocal();
      final endTime = ev.end?.dateTime ?? ev.end?.date?.toLocal();
      if (startTime == null || endTime == null) continue;

      final gId = ev.id;
      if (gId != null && syncedIds.contains(gId)) continue;

      final sameDayEvents = await EventService().getEventsForDate(startTime);
      final exists = sameDayEvents.any((e) =>
          e.title == (ev.summary ?? '(제목 없음)') &&
          e.startTime.year == startTime.year &&
          e.startTime.month == startTime.month &&
          e.startTime.day == startTime.day &&
          e.startTime.hour == startTime.hour &&
          e.startTime.minute == startTime.minute);
      if (exists) {
        if (gId != null) syncedIds.add(gId);
        continue;
      }

      await EventService().createEvent(
        title: ev.summary ?? '(제목 없음)',
        description: ev.description ?? '',
        startTime: startTime,
        endTime: endTime,
        location: ev.location ?? '',
        category: EventCategory.other,
        priority: 2,
        isAllDay: ev.start?.date != null,
      );
      if (gId != null) syncedIds.add(gId);
      inserted++;
    }

    await prefs.setStringList('google_synced_event_ids', syncedIds.toList());
    return inserted;
  }
}


