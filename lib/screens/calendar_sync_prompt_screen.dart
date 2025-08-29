import 'package:flutter/material.dart';
import '../services/calendar_sync_service.dart';
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
      // CalendarSyncService를 사용하여 동기화 실행
      final result = await CalendarSyncService().syncAll(readonly: false);
      
      messenger.showSnackBar(
        SnackBar(content: Text('구글 캘린더에서 $result개의 일정을 동기화했습니다.')),
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

  void _onSkip(BuildContext context) async {
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