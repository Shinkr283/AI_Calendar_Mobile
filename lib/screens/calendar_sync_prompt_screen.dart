import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_calendar_service.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../main.dart';

class CalendarSyncPromptScreen extends StatelessWidget {
  final VoidCallback? onSyncComplete;
  final VoidCallback? onSkip;

  const CalendarSyncPromptScreen({
    Key? key,
    this.onSyncComplete,
    this.onSkip,
  }) : super(key: key);

  Future<void> _onSync(BuildContext context) async {
    try {
      // 1. 구글 로그인 계정 accessToken 획득
      final googleUser = await GoogleSignIn().signIn();
      final googleAuth = await googleUser?.authentication;
      final accessToken = googleAuth?.accessToken;

      if (accessToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구글 인증에 실패했습니다.')),
        );
        return;
      }

      // 2. 구글 캘린더 일정 불러오기
      final service = GoogleCalendarService(accessToken);
      final gEvents = await service.fetchEvents();

      // 3. 구글 Event -> 앱 Event 변환 및 DB 저장
      int successCount = 0;
      for (final gEvent in gEvents) {
        if (gEvent.start?.dateTime == null || gEvent.end?.dateTime == null) continue;
        await EventService().createEvent(
          title: gEvent.summary ?? '제목 없음',
          description: gEvent.description ?? '',
          startTime: gEvent.start!.dateTime!.toLocal(),
          endTime: gEvent.end!.dateTime!.toLocal(),
          location: gEvent.location ?? '',
          category: EventCategory.personal, // 기본값, 필요시 매핑
          priority: EventPriority.medium, // 기본값, 필요시 매핑
          isAllDay: gEvent.start!.date != null,
          recurrenceRule: (gEvent.recurrence != null && gEvent.recurrence!.isNotEmpty)
              ? gEvent.recurrence!.first
              : null,
          attendees: gEvent.attendees?.map((a) => a.email ?? '').where((e) => e.isNotEmpty).toList() ?? [],
          color: '#2196F3', // 기본값, 필요시 매핑
        );
        successCount++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구글 캘린더에서 $successCount개의 일정을 동기화했습니다.')),
      );
      if (onSyncComplete != null) onSyncComplete!();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동기화 중 오류 발생: $e')),
      );
    }
  }

  void _onSkip(BuildContext context) {
    if (onSkip != null) onSkip!();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('구글 캘린더 동기화')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '기존 구글 캘린더의 일정을\nAI Calendar와 동기화할까요?',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _onSync(context),
                child: const Text('예, 동기화할래요'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _onSkip(context),
                child: const Text('아니오, 나중에 할래요'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 