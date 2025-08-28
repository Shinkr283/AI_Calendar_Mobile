import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import '../widgets/event_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/calendar_sync_service.dart';
import '../services/holiday_service.dart';
import '../services/native_alarm_service.dart';
import '../utils/database_test_utils.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForMonth(_focusedDay);
    // 동기화 화면은 로그인 후 바로 표시되므로 여기서는 제거
  }



  Future<void> _loadEventsForMonth(DateTime month) async {
    setState(() => _isLoading = true);
    final events = await EventService().getEventsForMonth(month);
    final holidays = await HolidayService().getHolidaysForYear(month.year);
    setState(() {
      _events = events;
      _holidays = holidays;
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
          selectedDate: _selectedDay, // 선택된 날짜 전달
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
        );
        
        print('✅ 일정 추가 성공: ${createdEvent.id}');
        
        // 알림 예약: 사용자가 선택한 분 전
        if (alarmMinutesBefore > 0) {
          try {
            // 기존 네이티브 알림 삭제 (중복 방지)
            await NativeAlarmService.cancelNativeAlarm(createdEvent.id.hashCode);
            
            // 네이티브 알림 예약
            final alarmTime = createdEvent.startTime.subtract(Duration(minutes: alarmMinutesBefore));
            final delaySeconds = alarmTime.difference(DateTime.now()).inSeconds;
            
            if (delaySeconds > 0) {
              await NativeAlarmService.scheduleNativeAlarm(
                title: '일정 알림',
                body: '${createdEvent.title} 일정이 곧 시작됩니다!',
                delaySeconds: delaySeconds,
                notificationId: createdEvent.id.hashCode,
              );
              print('🚨 네이티브 알림 예약 성공: ${alarmMinutesBefore}분 전 (ID: ${createdEvent.id.hashCode})');
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
              action: SnackBarAction(
                label: '재시도',
                onPressed: _onAddEvent,
              ),
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
          final alarmTime = updatedEvent.startTime.subtract(Duration(minutes: alarmMinutesBefore));
          final delaySeconds = alarmTime.difference(DateTime.now()).inSeconds;
          
          if (delaySeconds > 0) {
            await NativeAlarmService.scheduleNativeAlarm(
              title: '일정 알림',
              body: '${updatedEvent.title} 일정이 곧 시작됩니다!',
              delaySeconds: delaySeconds,
              notificationId: updatedEvent.id.hashCode,
            );
            print('🚨 일정 수정 네이티브 알림 예약 성공: ${alarmMinutesBefore}분 전 (ID: ${updatedEvent.id.hashCode})');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'test_db':
                  try {
                    await DatabaseTestUtils.testDatabaseConnection();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('데이터베이스 테스트 완료! 콘솔 로그를 확인하세요.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('데이터베이스 테스트 실패: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  break;
                case 'db_info':
                  try {
                    final info = await DatabaseTestUtils.getDatabaseInfo();
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('데이터베이스 정보'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('경로: ${info['databasePath']}'),
                                const SizedBox(height: 8),
                                const Text('테이블:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ...((info['tables'] as List).map((table) => Text('- $table'))),
                                const SizedBox(height: 8),
                                const Text('레코드 수:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ...((info['tableCounts'] as Map<String, int>).entries.map((entry) => 
                                  Text('- ${entry.key}: ${entry.value}개'))),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('닫기'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('데이터베이스 정보 조회 실패: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  break;
                case 'notification_permission':
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('🚨 네이티브 알림 시스템'),
                        content: const SingleChildScrollView(
                          child: Text(
                            '✅ 네이티브 AlarmManager 사용 중\n'
                            '🔧 안드로이드 시스템 레벨에서 직접 관리\n'
                            '⚡ 가장 강력한 알림 방식\n'
                            '🛡️ 배터리 최적화 무시\n'
                            '🔄 앱 종료 후에도 작동\n\n'
                            '📱 만약 알림이 안 온다면:\n'
                            '1. 휴대폰 재부팅\n'
                            '2. 앱 재설치\n'
                            '3. 제조사별 추가 알림 설정 확인\n'
                            '4. 방해 금지 모드 해제\n\n'
                            '🎯 네이티브 테스트로 확인하세요!',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    );
                  }
                  break;

                case 'clear_notifications':
                  try {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('알림 삭제 확인'),
                        content: const Text('모든 예약된 알림을 삭제하시겠습니까?'),
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
                    
                    if (confirmed == true) {
                      // 모든 네이티브 알림 삭제 (ID 1~999 범위에서 시도)
                      int canceledCount = 0;
                      for (int i = 1; i <= 999; i++) {
                        try {
                          await NativeAlarmService.cancelNativeAlarm(i);
                          canceledCount++;
                        } catch (e) {
                          // 무시 - 해당 ID에 알림이 없을 수 있음
                        }
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('모든 네이티브 알림이 삭제되었습니다. (시도된 수: $canceledCount)'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('알림 삭제 실패: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  break;


                case 'native_10_second_test':
                  try {
                    await NativeAlarmService.scheduleNativeTestAlarm();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🚨 네이티브 10초 후 알림이 예약되었습니다! 강력한 AlarmManager 사용'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    print('네이티브 10초 후 알림 예약 실패: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('네이티브 10초 후 알림 예약 실패: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                  break;

                case 'native_5_second_test':
                  try {
                    await NativeAlarmService.scheduleQuickNativeTestAlarm();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚡ 네이티브 5초 후 알림이 예약되었습니다! 초고속 확인'),
                          backgroundColor: Colors.purple,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    print('네이티브 5초 후 알림 예약 실패: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('네이티브 5초 후 알림 예약 실패: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                  break;

                case 'native_immediate_test':
                  try {
                    await NativeAlarmService.scheduleImmediateTestAlarm();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔔 즉시 네이티브 알림이 예약되었습니다! 1초 후 확인'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    print('즉시 네이티브 알림 예약 실패: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('즉시 네이티브 알림 예약 실패: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                  break;

                case 'native_fullscreen_test':
                  try {
                    await NativeAlarmService.scheduleFullScreenTestAlarm();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🚨 강력한 전체화면 알림이 예약되었습니다! 2초 후 반드시 표시됩니다!'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    print('강력한 전체화면 알림 예약 실패: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('강력한 전체화면 알림 예약 실패: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test_db',
                child: Row(
                  children: [
                    Icon(Icons.bug_report),
                    SizedBox(width: 8),
                    Text('DB 테스트'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'db_info',
                child: Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('DB 정보'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'notification_permission',
                child: Row(
                  children: [
                    Icon(Icons.notifications),
                    SizedBox(width: 8),
                    Text('네이티브 알림 상태'),
                  ],
                ),
              ),

              const PopupMenuItem(
                value: 'native_10_second_test',
                child: Row(
                  children: [
                    Text('🚨'),
                    SizedBox(width: 8),
                    Text('네이티브 10초 테스트'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'native_5_second_test',
                child: Row(
                  children: [
                    Text('⚡'),
                    SizedBox(width: 8),
                    Text('네이티브 5초 테스트'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'native_immediate_test',
                child: Row(
                  children: [
                    Text('🔔'),
                    SizedBox(width: 8),
                    Text('즉시 네이티브 테스트'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'native_fullscreen_test',
                child: Row(
                  children: [
                    Text('🚨'),
                    SizedBox(width: 8),
                    Text('강력한 전체화면 테스트'),
                  ],
                ),
              ),
            ],
          ), // PopupMenuButton 끝
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '구글 캘린더 동기화',
            onPressed: _onSyncWithGoogle,
          ),
        ], // actions 리스트 종료
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
                            style: const TextStyle(fontSize: 10, color: Colors.red),
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
                      Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                      Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                      Text('${day.day}', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      // 일정 제목 텍스트 제거 - 파란색 막대바와 겹침 방지
                    ],
                  ),
                );
              },
              markerBuilder: (context, day, events) {
                final monthEvents = _events
                    .where((e) => !e.isCompleted && (e.startTime.month == day.month || e.endTime.month == day.month))
                    .toList();
                monthEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
                
                // 🎯 각 일정에 대해 라인 할당 (겹치지 않도록)
                final Map<String, int> eventLineMap = {};
                final List<List<Event>> lines = [];
                
                for (final event in monthEvents) {
                  int assignedLine = -1;
                  
                  // 기존 라인들 중에서 겹치지 않는 라인 찾기
                  for (int i = 0; i < lines.length; i++) {
                    bool canFit = true;
                    for (final lineEvent in lines[i]) {
                      if (!(event.endTime.isBefore(lineEvent.startTime) || 
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
                  final startDate = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
                  final endDate = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
                  final currentDate = DateTime(day.year, day.month, day.day);
                  
                  return !currentDate.isBefore(startDate) && !currentDate.isAfter(endDate);
                }).toList();
                
                if (todayEvents.isEmpty) return const SizedBox.shrink();

                return Stack(
                  children: todayEvents.take(3).map((event) {
                    final idx = eventLineMap[event.id] ?? 0;
                    final isStart = isSameDay(event.startTime, day);
                    final isEnd = isSameDay(event.endTime, day);
                    final isSingle = isStart && isEnd;
                    
                    // 🎨 첫 번째 이미지처럼 연속된 막대 디자인
                    return Positioned(
                      left: isSingle ? 4 : (isStart ? 4 : 0),
                      right: isSingle ? 4 : (isEnd ? 4 : 0),
                      top: 24.0 + idx * 14.0, // 더 촘촘하게 배치
                      height: 12, // 더 얇게
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FC3F7), // 하늘색 계열
                          borderRadius: isSingle 
                            ? BorderRadius.circular(6)
                            : isStart 
                              ? const BorderRadius.horizontal(left: Radius.circular(6))
                              : isEnd 
                                ? const BorderRadius.horizontal(right: Radius.circular(6))
                                : BorderRadius.zero,
                        ),
                        child: isStart // 시작일에만 제목 표시
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Text(
                                  event.title.length > 7 ? event.title.substring(0, 7) + '…' : event.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(), // 중간일과 끝일에는 빈 공간
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
                : _getSelectedDayEvents().isEmpty
                    ? const Center(child: Text('선택된 날짜에 일정이 없습니다.'))
                    : ListView.builder(
                        itemCount: _getSelectedDayEvents().length,
                        itemBuilder: (context, index) {
                          final event = _getSelectedDayEvents()[index];
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
                              trailing: Text(event.alarmMinutesBefore.toString()),
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

  /// 선택된 날짜의 일정만 반환
  List<Event> _getSelectedDayEvents() {
    if (_selectedDay == null) return [];
    
    return _events.where((event) {
      // 🎯 날짜 범위 확인: 시작일 <= 선택된날 <= 종료일
      final startDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
      final endDate = DateTime(event.endTime.year, event.endTime.month, event.endTime.day);
      final selectedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      
      return !selectedDate.isBefore(startDate) && !selectedDate.isAfter(endDate);
    }).toList();
  }

  Future<void> _onSyncWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final inserted = await CalendarSyncService().syncCurrentMonth(readonly: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동기화 완료: ${inserted}건')),
      );
      await _loadEventsForMonth(_focusedDay);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동기화 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
} 