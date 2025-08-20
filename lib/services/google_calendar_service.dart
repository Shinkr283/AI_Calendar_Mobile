import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

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
    );
    return res.items ?? [];
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