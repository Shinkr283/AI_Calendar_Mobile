import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_calendar_service.dart';
import '../services/event_service.dart';
import '../main.dart';

class CalendarSyncPromptScreen extends StatelessWidget {
  final VoidCallback? onSyncComplete;
  final VoidCallback? onSkip;

  const CalendarSyncPromptScreen({
    super.key,
    this.onSyncComplete,
    this.onSkip,
  });

  Future<void> _onSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      // 1. 구글 로그인 계정 accessToken 획득
      final googleUser = await GoogleSignIn().signIn();
      final googleAuth = await googleUser?.authentication;
      final accessToken = googleAuth?.accessToken;

      if (accessToken == null) {
        messenger.showSnackBar(
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
          alarmMinutesBefore: 10,
        );
        successCount++;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('구글 캘린더에서 $successCount개의 일정을 동기화했습니다.')),
      );
      if (onSyncComplete != null) onSyncComplete!();
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      messenger.showSnackBar(
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