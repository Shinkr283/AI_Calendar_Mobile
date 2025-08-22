import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HolidayService {
  static final HolidayService _instance = HolidayService._internal();
  factory HolidayService() => _instance;
  HolidayService._internal();

  // Google Public Holidays (Korea) ICS
  // Public iCal feed, no auth required
  static const String _koreaHolidayIcsUrl =
      'https://calendar.google.com/calendar/ical/ko.south_korea%23holiday%40group.v.calendar.google.com/public/basic.ics';

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, String>> getHolidaysForYear(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'holidays_$year';
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      final Map<String, dynamic> m = json.decode(cached);
      return m.map((k, v) => MapEntry(k, v.toString()));
    }

    final map = await _fetchAndParseIcs(year);
    await prefs.setString(cacheKey, json.encode(map));
    return map;
  }

  Future<void> preloadForYear(int year) async {
    await getHolidaysForYear(year);
  }

  Future<Map<String, String>> _fetchAndParseIcs(int year) async {
    final res = await http.get(Uri.parse(_koreaHolidayIcsUrl));
    if (res.statusCode != 200) return {};
    final text = res.body;
    final lines = const LineSplitter().convert(text);

    final result = <String, String>{};
    String? summary;
    String? dtStart;
    bool inEvent = false;

    for (final raw in lines) {
      final line = raw.trim();
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        summary = null;
        dtStart = null;
        continue;
      }
      if (line == 'END:VEVENT') {
        if (inEvent && dtStart != null && summary != null) {
          // DTSTART can be like: DTSTART;VALUE=DATE:20250101 or DTSTART:20250101
          final dateStr = dtStart.substring(dtStart.length - 8); // YYYYMMDD
          final y = int.tryParse(dateStr.substring(0, 4));
          if (y == year) {
            final m = int.tryParse(dateStr.substring(4, 6)) ?? 1;
            final d = int.tryParse(dateStr.substring(6, 8)) ?? 1;
            final key = _fmtDate(DateTime(year, m, d));
            result[key] = summary;
          }
        }
        inEvent = false;
        continue;
      }
      if (!inEvent) continue;
      if (line.startsWith('SUMMARY:')) {
        summary = line.replaceFirst('SUMMARY:', '').trim();
      } else if (line.startsWith('DTSTART')) {
        final parts = line.split(':');
        if (parts.length == 2) {
          dtStart = parts[1].trim();
        }
      }
    }
    return result;
  }
}


