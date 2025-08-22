import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/event.dart' as local;

class GoogleCalendarService {
  final String accessToken;

  GoogleCalendarService(this.accessToken);

  Future<List<calendar.Event>> fetchEvents() async {
    final client = GoogleHttpClient(accessToken);
    final calendarApi = calendar.CalendarApi(client);

    // 'primary'는 기본 캘린더, 필요시 다른 캘린더 ID도 사용 가능
    final events = await calendarApi.events.list('primary');
    return events.items ?? [];
  }

  Future<List<calendar.Event>> fetchEventsInRange({
    required DateTime timeMin,
    required DateTime timeMax,
    bool singleEvents = true,
    String orderBy = 'startTime',
    String? timeZone,
    bool showDeleted = true,
  }) async {
    final client = GoogleHttpClient(accessToken);
    final api = calendar.CalendarApi(client);
    final res = await api.events.list(
      'primary',
      timeMin: timeMin.toUtc(),
      timeMax: timeMax.toUtc(),
      singleEvents: singleEvents,
      orderBy: orderBy,
      timeZone: timeZone,
      maxResults: 2500,
      showDeleted: showDeleted,
    );
    return res.items ?? [];
  }

  // ===== Local <-> Google 변환 및 쓰기 API =====
  calendar.EventDateTime _toEventDateTime(DateTime dt) {
    return calendar.EventDateTime()
      ..dateTime = dt.toUtc()
      ..timeZone = 'Asia/Seoul';
  }

  // all-day 변환은 현재 사용하지 않음

  calendar.Event _fromLocalEvent(local.Event e) {
    final ev = calendar.Event()
      ..summary = e.title
      ..description = e.description
      ..location = e.location;

    ev.start = _toEventDateTime(e.startTime);
    ev.end = _toEventDateTime(e.endTime);
    return ev;
  }

  Future<calendar.Event> createEventFromLocal(local.Event e) async {
    final client = GoogleHttpClient(accessToken);
    final api = calendar.CalendarApi(client);
    final ev = _fromLocalEvent(e);
    return await api.events.insert(ev, 'primary');
  }

  Future<calendar.Event> updateEventFromLocal(String eventId, local.Event e) async {
    final client = GoogleHttpClient(accessToken);
    final api = calendar.CalendarApi(client);
    final ev = _fromLocalEvent(e);
    return await api.events.update(ev, 'primary', eventId);
  }

  Future<void> deleteEventById(String eventId) async {
    final client = GoogleHttpClient(accessToken);
    final api = calendar.CalendarApi(client);
    await api.events.delete('primary', eventId);
  }
}

// accessToken을 헤더에 자동으로 붙여주는 커스텀 http.Client
class GoogleHttpClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = IOClient();

  GoogleHttpClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }
} 