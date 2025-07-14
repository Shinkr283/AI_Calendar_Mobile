import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import '../widgets/event_form.dart';
import 'calendar_sync_prompt_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

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
    _showSyncPromptIfNeeded();
  }

  Future<void> _showSyncPromptIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenSyncPrompt = prefs.getBool('hasSeenSyncPrompt') ?? false;
    if (!hasSeenSyncPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => CalendarSyncPromptScreen(
            onSyncComplete: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('hasSeenSyncPrompt', true);
              Navigator.maybePop(dialogContext);
            },
            onSkip: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('hasSeenSyncPrompt', true);
              Navigator.maybePop(dialogContext);
            },
          ),
        );
      });
    }
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

  void _onAddEvent() async {
    final result = await showDialog<Map<String, dynamic>>( // Event와 알림 분을 함께 받기 위해 Map으로 받음
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 추가'),
        content: EventForm(
          onSave: (event, alarmMinutesBefore) {
            Navigator.of(context).pop({
              'event': event,
              'alarmMinutesBefore': alarmMinutesBefore,
            });
          },
        ),
      ),
    );
    if (result != null) {
      final newEvent = result['event'] as Event;
      final alarmMinutesBefore = result['alarmMinutesBefore'] as int;
      await EventService().createEvent(
        title: newEvent.title,
        description: newEvent.description,
        startTime: newEvent.startTime,
        endTime: newEvent.endTime,
        location: newEvent.location,
        category: newEvent.category,
        priority: newEvent.priority,
        isAllDay: newEvent.isAllDay,
        recurrenceRule: newEvent.recurrenceRule,
        attendees: newEvent.attendees,
        color: newEvent.color,
      );
      // 알림 예약: 사용자가 선택한 분 전
      if (alarmMinutesBefore > 0) {
        await NotificationService().scheduleNotification(
          id: newEvent.id.hashCode,
          scheduledTime: newEvent.startTime.subtract(Duration(minutes: alarmMinutesBefore)),
          title: '일정 알림',
          body: '${newEvent.title} 일정이 곧 시작됩니다!',
        );
      }
      _loadEventsForDay(_selectedDay!);
    }
  }

  void _onEditEvent(Event event) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 수정'),
        content: EventForm(
          initialEvent: event,
          onSave: (e, alarmMinutesBefore) {
            Navigator.of(context).pop({
              'event': e,
              'alarmMinutesBefore': alarmMinutesBefore,
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 삭제 기능
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('일정 삭제'),
                  content: const Text('정말로 이 일정을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await EventService().deleteEvent(event.id);
                Navigator.of(context).pop();
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (result != null) {
      final updatedEvent = result['event'] as Event;
      final alarmMinutesBefore = result['alarmMinutesBefore'] as int;
      await EventService().updateEvent(updatedEvent);
      // 알림 예약: 사용자가 선택한 분 전
      if (alarmMinutesBefore > 0) {
        await NotificationService().scheduleNotification(
          id: updatedEvent.id.hashCode,
          scheduledTime: updatedEvent.startTime.subtract(Duration(minutes: alarmMinutesBefore)),
          title: '일정 알림',
          body: '${updatedEvent.title} 일정이 곧 시작됩니다!',
        );
      }
      _loadEventsForDay(_selectedDay!);
    } else {
      // 삭제된 경우에도 목록 갱신
      _loadEventsForDay(_selectedDay!);
    }
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
                                _onEditEvent(event);
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