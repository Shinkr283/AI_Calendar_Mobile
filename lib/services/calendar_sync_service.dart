import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_calendar_service.dart';
import '../services/event_service.dart';
import '../models/event.dart';

class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  factory CalendarSyncService() => _instance;
  CalendarSyncService._internal();

  Future<String?> _ensureAccessToken({bool readonly = true}) async {
    final scopes = <String>[
      'email',
      readonly
          ? 'https://www.googleapis.com/auth/calendar.readonly'
          : 'https://www.googleapis.com/auth/calendar',
    ];

    final google = GoogleSignIn(scopes: scopes);
    GoogleSignInAccount? account = await google.signInSilently(suppressErrors: true);
    account ??= await google.signIn();
    if (account == null) return null;
    await google.requestScopes(scopes);
    final auth = await account.authentication;
    return auth.accessToken;
  }

  Future<int> syncCurrentMonth({bool readonly = false}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return syncRange(start: start, end: end, readonly: readonly);
  }

  Future<int> syncRange({
    required DateTime start,
    required DateTime end,
    bool readonly = false,
  }) async {
    final token = await _ensureAccessToken(readonly: readonly);
    if (token == null || token.isEmpty) {
      throw Exception('구글 로그인이 필요합니다.');
    }

    final svc = GoogleCalendarService(token);
    late final List<calendar.Event> items;
    final prefs = await SharedPreferences.getInstance();
    try {
      // 마지막 동기화 기준 필터(선택): updatedMin
      final lastUpdatedMs = prefs.getInt('google_last_sync_updated_ms') ?? 0;
      final updatedMin = lastUpdatedMs > 0 ? DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs) : null;
      items = await svc.fetchEventsInRange(
        timeMin: start,
        timeMax: end,
        singleEvents: true,
        orderBy: 'startTime',
        timeZone: 'Asia/Seoul',
        showDeleted: true,
        updatedMin: updatedMin,
        fields: 'items(id,status,summary,description,location,updated,start,end),nextPageToken'
      );
    } catch (e) {
      // 401 대응: 재인증 후 1회 재시도
      final retryToken = await _ensureAccessToken(readonly: readonly);
      if (retryToken == null) rethrow;
      final retrySvc = GoogleCalendarService(retryToken);
      items = await retrySvc.fetchEventsInRange(
        timeMin: start,
        timeMax: end,
        singleEvents: true,
        orderBy: 'startTime',
        timeZone: 'Asia/Seoul',
        showDeleted: true,
        fields: 'items(id,status,summary,description,location,updated,start,end),nextPageToken'
      );
    }

    // prefs 이미 로드됨
    final syncedIds = prefs.getStringList('google_synced_event_ids')?.toSet() ?? <String>{};
    // 삭제 대기 큐 처리(로컬에서 삭제된 건을 구글에서도 삭제)
    if (!readonly) {
      final pendingDeletes = prefs.getStringList('pending_google_deletes') ?? <String>[];
      if (pendingDeletes.isNotEmpty) {
        for (final gid in List<String>.from(pendingDeletes)) {
          try {
            await GoogleCalendarService(token).deleteEventById(gid);
            pendingDeletes.remove(gid);
          } catch (_) {
            // 실패 시 다음 동기화 때 재시도
          }
        }
        await prefs.setStringList('pending_google_deletes', pendingDeletes);
      }
    }

    var inserted = 0;
    var pushed = 0;

    // ---- DB I/O 줄이기: 로컬 이벤트 선로드/맵화 ----
    // 기간 내 로컬 이벤트를 미리 한꺼번에 로드하여 googleEventId 및 (title,start) 기준으로 맵 구성
    final localEventsInRange = await EventService().getEvents(startDate: start, endDate: end);
    final Map<String, Event> localByGid = {
      for (final e in localEventsInRange)
        if (e.googleEventId != null && e.googleEventId!.isNotEmpty) e.googleEventId!: e
    };
    final Map<String, Event> localByTitleStartKey = {
      for (final e in localEventsInRange)
        '${e.title.toLowerCase()}|${e.startTime.millisecondsSinceEpoch}': e
    };
    for (final ev in items) {
      final startTime = ev.start?.dateTime ?? ev.start?.date?.toLocal();
      final endTime = ev.end?.dateTime ?? ev.end?.date?.toLocal();
      // 삭제된/취소된 이벤트 처리
      final gId = ev.id;
      if (ev.status == 'cancelled') {
        if (gId != null) {
          final localMatch = await EventService().getEventByGoogleId(gId);
          if (localMatch != null) {
            await EventService().deleteEvent(localMatch.id);
            syncedIds.remove(gId);
          }
        }
        // 취소된 이벤트는 삽입/업데이트 대상이 아님
        continue;
      }

      if (startTime == null || endTime == null) continue;

      // Google ID로 로컬 이벤트 매칭 후 최신 정보로 업데이트 (선로드 맵 사용)
      if (gId != null) {
        final local = localByGid[gId];
        if (local != null) {
          // 구글/로컬 중 더 최신의 수정본을 채택
          final googleUpdated = ev.updated?.toLocal();
          final isGoogleNewer = googleUpdated != null && googleUpdated.isAfter(local.updatedAt);

          if (isGoogleNewer) {
            final updatedLocal = local.copyWith(
              title: ev.summary ?? local.title,
              description: ev.description ?? local.description,
              startTime: startTime,
              endTime: endTime,
              location: ev.location ?? local.location,
              updatedAt: googleUpdated,
            );
            await EventService().updateEvent(updatedLocal);
          } else if (!readonly) {
            // 로컬이 더 최신이면 구글로 푸시
            await svc.updateEventFromLocal(gId, local);
          }

          syncedIds.add(gId);
          continue;
        }
        // 수동 생성된 로컬 이벤트 매칭 (제목 및 시작 시간 기준) - 선계산 맵 사용
        final manualKey = '${(ev.summary ?? '').toLowerCase()}|${startTime.millisecondsSinceEpoch}';
        final manualMatch = localByTitleStartKey[manualKey];
        if (manualMatch != null) {
          final updatedLocal = manualMatch.copyWith(
            googleEventId: gId,
            updatedAt: DateTime.now(),
          );
          await EventService().updateEvent(updatedLocal);
          syncedIds.add(gId);
          // 맵 갱신
          localByGid[gId] = updatedLocal;
          continue;
        }
        // 로컬에 해당 Google 이벤트가 없으면 새로 삽입
        final createdLocal = await EventService().createEvent(
          title: ev.summary ?? '(제목 없음)',
          description: ev.description ?? '',
          startTime: startTime,
          endTime: endTime,
          location: ev.location ?? '',
          alarmMinutesBefore: 10,
          isAllDay: ev.start?.dateTime == null && ev.start?.date != null,
        );
        final bound = createdLocal.copyWith(
          googleEventId: gId,
          updatedAt: DateTime.now(),
        );
        await EventService().updateEvent(bound);
        syncedIds.add(gId);
        // 맵 갱신
        localByGid[gId] = bound;
        localByTitleStartKey['${bound.title.toLowerCase()}|${bound.startTime.millisecondsSinceEpoch}'] = bound;
        inserted++;
      }
      continue;
    }

    await prefs.setStringList('google_synced_event_ids', syncedIds.toList());
    // 마지막 동기화 시간 갱신(현재 시각 기준)
    await prefs.setInt('google_last_sync_updated_ms', DateTime.now().millisecondsSinceEpoch);
    // ---- Push local changes to Google when not readonly ----
    if (!readonly) {
      final localEvents = await EventService().getEvents(
        startDate: start,
        endDate: end,
      );
      final googleIdsInRange = items.where((e) => e.id != null).map((e) => e.id!).toSet();
      final lastSyncedMap = Map<String, String>.from(
        prefs.getStringList('google_event_last_synced')
                ?.map((e) => e.split('|'))
                .where((parts) => parts.length == 2)
                .fold<Map<String, String>>({}, (acc, parts) {
                  acc[parts[0]] = parts[1];
                  return acc;
                }) ?? {},
      );
      for (final e in localEvents) {
        if (e.googleEventId == null || e.googleEventId!.isEmpty) {
          final created = await svc.createEventFromLocal(e);
          // 로컬에 Google ID 반영
          final updated = e.copyWith(googleEventId: created.id, updatedAt: DateTime.now());
          await EventService().updateEvent(updated);
          lastSyncedMap[created.id ?? ''] = updated.updatedAt.millisecondsSinceEpoch.toString();
          pushed++;
        } else {
          // 로컬 존재, 구글에 삭제되었는지 확인
          if (!googleIdsInRange.contains(e.googleEventId!)) {
            // 구글에 없다면 로컬 삭제로 간주(또는 복원 정책 고려). 여기서는 삭제 동기화
            await EventService().deleteEvent(e.id);
          } else {
            // 변경 감지: 마지막 동기화 시간보다 로컬 updatedAt이 크면 구글 업데이트
            final last = int.tryParse(lastSyncedMap[e.googleEventId!] ?? '0') ?? 0;
            if (e.updatedAt.millisecondsSinceEpoch > last) {
              await svc.updateEventFromLocal(e.googleEventId!, e);
              lastSyncedMap[e.googleEventId!] = DateTime.now().millisecondsSinceEpoch.toString();
            }
          }
        }
      }
      // last synced 저장
      final persisted = lastSyncedMap.entries
          .where((e) => e.key.isNotEmpty)
          .map((e) => '${e.key}|${e.value}')
          .toList();
      await prefs.setStringList('google_event_last_synced', persisted);
    }

    return inserted + pushed;
  }
}


