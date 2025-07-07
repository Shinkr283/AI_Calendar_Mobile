import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/event_service.dart';
import '../models/event.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForDay(_selectedDay!);
  }

  Future<void> _loadEventsForDay(DateTime day) async {
    setState(() => _isLoading = true);
    final events = await EventService().getEventsForDate(day);
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _loadEventsForDay(selectedDay);
  }

  void _onFormatChanged(CalendarFormat format) {
    setState(() {
      _calendarFormat = format;
    });
  }

  void _onAddEvent() {
    // TODO: 일정 추가 다이얼로그/화면 띄우기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: _onFormatChanged,
            eventLoader: (day) =>
                _selectedDay != null && isSameDay(day, _selectedDay!) ? _events : [],
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: [
              _calendarFormat == CalendarFormat.month,
              _calendarFormat == CalendarFormat.week,
              _calendarFormat == CalendarFormat.twoWeeks,
            ],
            onPressed: (index) {
              setState(() {
                if (index == 0) _calendarFormat = CalendarFormat.month;
                if (index == 1) _calendarFormat = CalendarFormat.week;
                if (index == 2) _calendarFormat = CalendarFormat.twoWeeks;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('월'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('주'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('2주'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('일정이 없습니다.'))
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              title: Text(event.title),
                              subtitle: Text(event.description),
                              trailing: Text(EventCategory.getDisplayName(event.category)),
                              onTap: () {
                                // TODO: 일정 상세/수정 화면 띄우기
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddEvent,
        child: const Icon(Icons.add),
        tooltip: '일정 추가',
      ),
    );
  }
} 