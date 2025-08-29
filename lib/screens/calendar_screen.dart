import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import '../widgets/event_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/calendar_sync_service.dart';
import '../services/holiday_service.dart';
import '../services/native_alarm_service.dart';
import '../services/settings_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];
  Map<String, String> _holidays = {};
  bool _isLoading = false;
  StartingDayOfWeek _startingDayOfWeek = StartingDayOfWeek.sunday;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForMonth(_focusedDay);
    _loadWeekStartDay();
    // 동기화 화면은 로그인 후 바로 표시되므로 여기서는 제거
  }

  Future<void> _loadEventsForMonth(DateTime month) async {
    setState(() => _isLoading = true);
    // 월별 일정 대신 모든 일정을 로드 (월 상관없이 표시)
    final events = await EventService().getEvents();
    final holidays = await HolidayService().getHolidaysForYear(month.year);
    setState(() {
      _events = events;
      _holidays = holidays;
      _isLoading = false;
    });
  }

  Future<void> _loadWeekStartDay() async {
    try {
      final settingsService = SettingsService();
      final weekStartDay = await settingsService.getWeekStartDay();
      setState(() {
        _startingDayOfWeek = weekStartDay == 0
            ? StartingDayOfWeek.sunday
            : StartingDayOfWeek.monday;
      });
    } catch (e) {
      print('주 시작 요일 로드 실패: $e');
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    // 날짜를 선택해도 월 전체 일정을 유지
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
    });
    // 월이 변경되면 해당 월의 일정을 로드
    _loadEventsForMonth(focusedDay);
  }

  void _onAddEvent() async {
    final result = await showDialog<Map<String, dynamic>>(
      // Event와 알림 분을 함께 받기 위해 Map으로 받음
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 추가'),
        content: EventForm(
          selectedDate: _selectedDay, // 선택된 날짜 전달
          onSave: (event, alarmMinutesBefore) {
            Navigator.of(
              context,
            ).pop({'event': event, 'alarmMinutesBefore': alarmMinutesBefore});
          },
        ),
      ),
    );

    if (result != null) {
      try {
        setState(() => _isLoading = true);

        final newEvent = result['event'] as Event;
        final alarmMinutesBefore = result['alarmMinutesBefore'] as int;

        print('📝 일정 추가 시도: ${newEvent.title}');
        print('🕐 시작 시간: ${newEvent.startTime}');
        print('🕐 종료 시간: ${newEvent.endTime}');

        final createdEvent = await EventService().createEvent(
          title: newEvent.title,
          description: newEvent.description,
          startTime: newEvent.startTime,
          endTime: newEvent.endTime,
          location: newEvent.location,
          alarmMinutesBefore: newEvent.alarmMinutesBefore, // 알림 시간 전달
          priority: newEvent.priority, // 우선순위 전달
          labelColor: newEvent.labelColor, // 라벨 색상 추가
        );

        print('✅ 일정 추가 성공: ${createdEvent.id}');

        // 알림 예약: 사용자가 선택한 분 전
        if (alarmMinutesBefore > 0) {
          try {
            // 기존 네이티브 알림 삭제 (중복 방지)
            await NativeAlarmService.cancelNativeAlarm(
              createdEvent.id.hashCode,
            );

            // 네이티브 알림 예약
            final alarmTime = createdEvent.startTime.subtract(
              Duration(minutes: alarmMinutesBefore),
            );
            final delaySeconds = alarmTime.difference(DateTime.now()).inSeconds;

            if (delaySeconds > 0) {
              await NativeAlarmService.scheduleNativeAlarm(
                title: '일정 알림',
                body: '${createdEvent.title} 일정이 곧 시작됩니다!',
                delaySeconds: delaySeconds,
                notificationId: createdEvent.id.hashCode,
              );
              print(
                '🚨 네이티브 알림 예약 성공: ${alarmMinutesBefore}분 전 (ID: ${createdEvent.id.hashCode})',
              );
            } else {
              print('⚠️ 알림 시간이 이미 지났습니다.');
            }
          } catch (e) {
            print('⚠️ 네이티브 알림 예약 실패: $e');
            // 알림 실패는 일정 추가를 막지 않음
          }
        }

        await _loadEventsForMonth(_focusedDay);
        print('🔄 캘린더 새로고침 완료');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('일정이 성공적으로 추가되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e, stackTrace) {
        print('❌ 일정 추가 실패: $e');
        print('📍 스택 트레이스: $stackTrace');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('일정 추가에 실패했습니다: ${e.toString()}'),
              backgroundColor: Colors.red,
              action: SnackBarAction(label: '재시도', onPressed: _onAddEvent),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
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
            Navigator.of(
              context,
            ).pop({'event': e, 'alarmMinutesBefore': alarmMinutesBefore});
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
                // 일정 삭제 전에 관련 네이티브 알림도 삭제
                try {
                  await NativeAlarmService.cancelNativeAlarm(event.id.hashCode);
                  print('🗑️ 일정 삭제 시 네이티브 알림도 함께 삭제: ${event.id.hashCode}');
                } catch (e) {
                  print('⚠️ 네이티브 알림 삭제 실패: $e');
                }

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
        try {
          // 기존 네이티브 알림 삭제 (중복 방지)
          await NativeAlarmService.cancelNativeAlarm(updatedEvent.id.hashCode);

          // 네이티브 알림 예약
          final alarmTime = updatedEvent.startTime.subtract(
            Duration(minutes: alarmMinutesBefore),
          );
          final delaySeconds = alarmTime.difference(DateTime.now()).inSeconds;

          if (delaySeconds > 0) {
            await NativeAlarmService.scheduleNativeAlarm(
              title: '일정 알림',
              body: '${updatedEvent.title} 일정이 곧 시작됩니다!',
              delaySeconds: delaySeconds,
              notificationId: updatedEvent.id.hashCode,
            );
            print(
              '🚨 일정 수정 네이티브 알림 예약 성공: ${alarmMinutesBefore}분 전 (ID: ${updatedEvent.id.hashCode})',
            );
          } else {
            print('⚠️ 알림 시간이 이미 지났습니다.');
          }
        } catch (e) {
          print('⚠️ 네이티브 알림 예약 실패: $e');
        }
      } else {
        // 알림 시간이 0분이면 기존 네이티브 알림 삭제
        try {
          await NativeAlarmService.cancelNativeAlarm(updatedEvent.id.hashCode);
          print('🗑️ 기존 네이티브 알림 삭제 완료 (ID: ${updatedEvent.id.hashCode})');
        } catch (e) {
          print('⚠️ 기존 네이티브 알림 삭제 실패: $e');
        }
      }
      _loadEventsForMonth(_focusedDay);
    } else {
      // 삭제된 경우에도 목록 갱신
      _loadEventsForMonth(_focusedDay);
    }
  }

     String _fmtDate(DateTime d) =>
       '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

   /// 일정의 라벨 색상을 안전하게 파싱하는 헬퍼 함수
   Color _getEventColor(Event event) {
     try {
       final colorString = event.labelColor.isNotEmpty ? event.labelColor : '#FF0000';
       if (colorString.startsWith('#') && colorString.length == 7) {
         return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
       } else {
         return Colors.red; // 기본값
       }
     } catch (e) {
       print('색상 파싱 오류: ${event.labelColor} -> 기본값 사용');
       return Colors.red;
     }
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 상단 메뉴 버튼
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'sync_google_calendar') {
                        _onSyncWithGoogle();
                      } else if (value == 'week_start_day') {
                        _showWeekStartDayDialog();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'sync_google_calendar',
                        child: Row(
                          children: [
                            Icon(Icons.sync),
                            SizedBox(width: 8),
                            Text('구글 캘린더 동기화'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'week_start_day',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_view_week),
                            SizedBox(width: 8),
                            Text('주 시작 요일'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 캘린더
            Expanded(
              child: Column(
                children: [
                  TableCalendar<Event>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: _startingDayOfWeek,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onPageChanged: _onPageChanged,
                    eventLoader: (day) => _events
                        .where((e) => isSameDay(e.startTime, day))
                        .toList(),
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
                        return Container(
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 4),
                              Text('${day.day}', textAlign: TextAlign.center),
                              // 일정 제목 텍스트 제거 - 파란색 막대바와 겹침 방지
                              if (_holidays.containsKey(_fmtDate(day)))
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _holidays[_fmtDate(day)]!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.red,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                      todayBuilder: (context, day, focusedDay) {
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
                              Text(
                                '${day.day}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // 일정 제목 텍스트 제거 - 파란색 막대바와 겹침 방지
                            ],
                          ),
                        );
                      },
                      selectedBuilder: (context, day, focusedDay) {
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
                              Text(
                                '${day.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // 일정 제목 텍스트 제거 - 파란색 막대바와 겹침 방지
                            ],
                          ),
                        );
                      },
                      outsideBuilder: (context, day, focusedDay) {
                        return Container(
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${day.day}',
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              // 일정 제목 텍스트 제거 - 파란색 막대바와 겹침 방지
                            ],
                          ),
                        );
                      },
                      markerBuilder: (context, day, events) {
                        final monthEvents = _events
                            .where(
                              (e) =>
                                  !e.isCompleted &&
                                  (e.startTime.month == day.month ||
                                      e.endTime.month == day.month),
                            )
                            .toList();
                        monthEvents.sort(
                          (a, b) => a.startTime.compareTo(b.startTime),
                        );

                        // 🎯 각 일정에 대해 라인 할당 (겹치지 않도록)
                        final Map<String, int> eventLineMap = {};
                        final List<List<Event>> lines = [];

                        for (final event in monthEvents) {
                          int assignedLine = -1;

                          // 기존 라인들 중에서 겹치지 않는 라인 찾기
                          for (int i = 0; i < lines.length; i++) {
                            bool canFit = true;
                            for (final lineEvent in lines[i]) {
                              if (!(event.endTime.isBefore(
                                    lineEvent.startTime,
                                  ) ||
                                  event.startTime.isAfter(lineEvent.endTime))) {
                                canFit = false;
                                break;
                              }
                            }
                            if (canFit) {
                              assignedLine = i;
                              break;
                            }
                          }

                          // 새로운 라인 생성
                          if (assignedLine == -1) {
                            assignedLine = lines.length;
                            lines.add([]);
                          }

                          lines[assignedLine].add(event);
                          eventLineMap[event.id] = assignedLine;
                        }

                        final todayEvents = monthEvents.where((e) {
                          // 🎯 날짜 범위 확인: 시작일 <= 현재날 <= 종료일
                          final startDate = DateTime(
                            e.startTime.year,
                            e.startTime.month,
                            e.startTime.day,
                          );
                          final endDate = DateTime(
                            e.endTime.year,
                            e.endTime.month,
                            e.endTime.day,
                          );
                          final currentDate = DateTime(
                            day.year,
                            day.month,
                            day.day,
                          );

                          return !currentDate.isBefore(startDate) &&
                              !currentDate.isAfter(endDate);
                        }).toList();

                        if (todayEvents.isEmpty) return const SizedBox.shrink();

                                                 // 최대 2개 일정만 표시하고, 나머지는 "+N"으로 표시
                         final displayEvents = todayEvents.take(2).toList();
                         final remainingCount = todayEvents.length - displayEvents.length;
                         
                         return Stack(
                           children: [
                             // 첫 번째 일정
                             if (displayEvents.isNotEmpty)
                               Positioned(
                                 left: 4,
                                 top: 24.0,
                                 child: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     // 라벨 색깔 점
                                     Container(
                                       width: 6,
                                       height: 6,
                                       decoration: BoxDecoration(
                                         color: _getEventColor(displayEvents[0]),
                                         shape: BoxShape.circle,
                                       ),
                                     ),
                                     const SizedBox(width: 6),
                                     // 제목 텍스트
                                     Flexible(
                                       child: Text(
                                         displayEvents[0].title,
                                         style: const TextStyle(
                                           color: Colors.black,
                                           fontSize: 10,
                                           fontWeight: FontWeight.normal,
                                         ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                                                           // 두 번째 일정
                              if (displayEvents.length > 1)
                                Positioned(
                                  left: 4,
                                  top: 35.0, // 첫 번째 일정과 적당한 간격으로 조정
                                  child: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     // 라벨 색깔 점
                                     Container(
                                       width: 6,
                                       height: 6,
                                       decoration: BoxDecoration(
                                         color: _getEventColor(displayEvents[1]),
                                         shape: BoxShape.circle,
                                       ),
                                     ),
                                     const SizedBox(width: 6),
                                     // 제목 텍스트
                                     Flexible(
                                       child: Text(
                                         displayEvents[1].title,
                                         style: const TextStyle(
                                           color: Colors.black,
                                           fontSize: 10,
                                           fontWeight: FontWeight.normal,
                                         ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                                                           // 추가 일정이 있으면 "+N" 표시
                              if (remainingCount > 0)
                                Positioned(
                                  left: 4,
                                  top: 46.0, // 두 번째 일정 아래 (간격 조정)
                                  child: Text(
                                   '+$remainingCount',
                                   style: const TextStyle(
                                     color: Colors.grey,
                                     fontSize: 9,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ),
                           ],
                         );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _getSelectedDayEvents().isEmpty
                        ? const Center(child: Text('선택된 날짜에 일정이 없습니다.'))
                        : ListView.builder(
                            itemCount: _getSelectedDayEvents().length,
                            itemBuilder: (context, index) {
                              final event = _getSelectedDayEvents()[index];
                              
                              // 라벨 색상 안전하게 파싱
                              Color titleColor;
                              try {
                                final colorString = event.labelColor.isNotEmpty ? event.labelColor : '#FF0000';
                                if (colorString.startsWith('#') && colorString.length == 7) {
                                  titleColor = Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
                                } else {
                                  titleColor = Colors.red; // 기본값
                                }
                              } catch (e) {
                                print('일정 목록 색상 파싱 오류: ${event.labelColor} -> 기본값 사용');
                                titleColor = Colors.red;
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  title: Text(
                                    event.title,
                                    style: const TextStyle(
                                      color: Colors.black, // 검정색으로 고정
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (event.description.isNotEmpty)
                                        Text(event.description),
                                      if (event.location.isNotEmpty) ...[
                                        if (event.description.isNotEmpty)
                                          const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.place,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
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
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (event.priority > 0) ...[
                                        ...List.generate(
                                          event.priority,
                                          (index) => Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        event.alarmMinutesBefore > 0
                                            ? '${event.alarmMinutesBefore}분 전'
                                            : '알림 없음',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddEvent,
        child: const Icon(Icons.add),
        tooltip: '일정 추가',
      ),
    );
  }

  /// 선택된 날짜의 일정만 반환
  List<Event> _getSelectedDayEvents() {
    if (_selectedDay == null) return [];

    return _events.where((event) {
      // 🎯 날짜 범위 확인: 시작일 <= 선택된날 <= 종료일
      final startDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      final endDate = DateTime(
        event.endTime.year,
        event.endTime.month,
        event.endTime.day,
      );
      final selectedDate = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );

      return !selectedDate.isBefore(startDate) &&
          !selectedDate.isAfter(endDate);
    }).toList();
  }

  Future<void> _onSyncWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 전체 동기화 실행 (3개월 전후)
      final result = await CalendarSyncService().syncAll(readonly: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('동기화 완료: ${result}건 처리됨')));
      await _loadEventsForMonth(_focusedDay);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('동기화 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

    Future<void> _showWeekStartDayDialog() async {
    final settingsService = SettingsService();
    final currentWeekStartDay = await settingsService.getWeekStartDay();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주 시작 요일 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('일요일'),
              value: 0,
              groupValue: currentWeekStartDay,
              onChanged: (value) async {
                await settingsService.setWeekStartDay(value!);
                if (mounted) {
                  setState(() {
                    _startingDayOfWeek = StartingDayOfWeek.sunday;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('주 시작 요일이 일요일로 변경되었습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            RadioListTile<int>(
              title: const Text('월요일'),
              value: 1,
              groupValue: currentWeekStartDay,
              onChanged: (value) async {
                await settingsService.setWeekStartDay(value!);
                if (mounted) {
                  setState(() {
                    _startingDayOfWeek = StartingDayOfWeek.monday;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('주 시작 요일이 월요일로 변경되었습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
