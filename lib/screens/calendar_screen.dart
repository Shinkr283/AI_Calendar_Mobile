import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import '../widgets/event_form.dart';
import 'calendar_sync_prompt_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          category: newEvent.category,
          priority: newEvent.priority,
          isAllDay: newEvent.isAllDay,
          recurrenceRule: newEvent.recurrenceRule,
          attendees: newEvent.attendees,
          color: newEvent.color,
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
          ),
        ],
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