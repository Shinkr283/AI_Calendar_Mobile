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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForMonth(_focusedDay);
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

  Future<void> _loadEventsForMonth(DateTime month) async {
    setState(() => _isLoading = true);
    final events = await EventService().getEventsForMonth(month);
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
    // 날짜를 선택해도 월 전체 일정을 유지
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
      _loadEventsForMonth(_focusedDay);
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
      _loadEventsForMonth(_focusedDay);
    } else {
      // 삭제된 경우에도 목록 갱신
      _loadEventsForMonth(_focusedDay);
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
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            eventLoader: (day) => _events.where((e) => isSameDay(e.startTime, day)).toList(),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              markerMargin: EdgeInsets.zero,
              markersMaxCount: 10,
              markerSize: 0,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dayEvents = _events.where((e) => isSameDay(e.startTime, day)).toList();
                return Container(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 4),
                      Text('${day.day}', textAlign: TextAlign.center),
                      if (dayEvents.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dayEvents.first.title.length > 8
                                ? dayEvents.first.title.substring(0, 8) + '...'
                                : dayEvents.first.title,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blueAccent,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                final dayEvents = _events.where((e) => isSameDay(e.startTime, day)).toList();
                return Container(
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 4),
                      Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      if (dayEvents.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dayEvents.first.title.length > 8
                                ? dayEvents.first.title.substring(0, 8) + '...'
                                : dayEvents.first.title,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blueAccent,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final dayEvents = _events.where((e) => isSameDay(e.startTime, day)).toList();
                return Container(
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 4),
                      Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      if (dayEvents.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dayEvents.first.title.length > 8
                                ? dayEvents.first.title.substring(0, 8) + '...'
                                : dayEvents.first.title,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              },
              outsideBuilder: (context, day, focusedDay) {
                final dayEvents = _events.where((e) => isSameDay(e.startTime, day)).toList();
                return Container(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 4),
                      Text('${day.day}', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      if (dayEvents.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dayEvents.first.title.length > 8
                                ? dayEvents.first.title.substring(0, 8) + '...'
                                : dayEvents.first.title,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              },
              markerBuilder: (context, day, events) {
                final monthEvents = _events
                    .where((e) => !e.isAllDay && !e.isCompleted && (e.startTime.month == day.month || e.endTime.month == day.month))
                    .toList();
                monthEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
                final Map<String, int> eventLineMap = {};
                int line = 0;
                for (final event in monthEvents) {
                  eventLineMap[event.id] = line++;
                }

                final todayEvents = monthEvents.where((e) => !e.startTime.isAfter(day) && !e.endTime.isBefore(day)).toList();
                if (todayEvents.isEmpty) return const SizedBox.shrink();

                return Stack(
                  children: todayEvents.take(3).map((event) {
                    final idx = eventLineMap[event.id] ?? 0;
                    final isStart = isSameDay(event.startTime, day);
                    final isEnd = isSameDay(event.endTime, day);
                    final isSingle = isStart && isEnd;
                    BorderRadius borderRadius;
                    double left = 2, right = 2;
                    if (isSingle) {
                      borderRadius = BorderRadius.circular(6);
                    } else if (isStart) {
                      borderRadius = const BorderRadius.horizontal(left: Radius.circular(6));
                      right = 0;
                    } else if (isEnd) {
                      borderRadius = const BorderRadius.horizontal(right: Radius.circular(6));
                      left = 0;
                    } else {
                      borderRadius = BorderRadius.zero;
                      left = 0;
                      right = 0;
                    }
                    return Positioned(
                      left: left,
                      right: right,
                      top: 24.0 + idx * 16.0,
                      height: 16,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.lightBlue,
                          borderRadius: borderRadius,
                        ),
                        child: Text(
                          event.title.length > 8 ? event.title.substring(0, 8) + '…' : event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (event.description.isNotEmpty) 
                                    Text(event.description),
                                  if (event.location.isNotEmpty) ...[
                                    if (event.description.isNotEmpty) const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.place, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            event.location,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  Text(
                                    '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')} - ${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
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