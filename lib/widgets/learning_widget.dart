import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/chat_screen.dart';
import '../services/chat_service.dart';

class LearningWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const LearningWidget({
    super.key,
    required this.isEnabled,
    this.onTap,
  });

  @override
  State<LearningWidget> createState() => _LearningWidgetState();
}

class _LearningWidgetState extends State<LearningWidget> {
  String _learningTip = '';
  String _motivationMessage = '';

  final List<String> _learningTips = [
    '25분 집중 학습 후 5분 휴식을 취하세요',
    '새로운 개념을 배울 때는 예시를 찾아보세요',
    '복습은 학습의 핵심입니다. 정기적으로 되돌아보세요',
    '실습을 통해 이론을 확실히 이해하세요',
    '다른 사람에게 설명해보며 지식을 정리하세요',
    '꾸준함이 가장 큰 무기입니다',
    '실수는 학습의 일부입니다. 두려워하지 마세요',
    '목표를 작은 단위로 나누어 달성하세요',
  ];

  final List<String> _motivations = [
    '오늘 한 걸음이 내일의 큰 도약이 됩니다',
    '지금 시작하는 것이 가장 빠른 방법입니다',
    '작은 진전도 진전입니다. 포기하지 마세요',
    '당신은 생각보다 더 똑똑합니다',
    '학습은 인생의 가장 좋은 투자입니다',
    '꾸준함이 천재를 만듭니다',
    '오늘의 노력이 내일의 성공을 만듭니다',
    '배움에는 끝이 없습니다. 계속 도전하세요',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      _generateLearningContent();
    }
  }

  @override
  void didUpdateWidget(LearningWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _generateLearningContent();
    }
  }

  void _generateLearningContent() {
    if (!widget.isEnabled) return;

    final now = DateTime.now();
    final hour = now.hour;
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    // 시간대별 학습 팁
    if (hour >= 6 && hour < 10) {
      _learningTip = '아침은 학습하기 좋은 시간입니다. 중요한 내용을 먼저!';
    } else if (hour >= 10 && hour < 14) {
      _learningTip = '점심 시간에는 복습을 해보세요';
    } else if (hour >= 14 && hour < 18) {
      _learningTip = '오후에는 새로운 내용을 학습하기 좋은 시간입니다';
    } else if (hour >= 18 && hour < 22) {
      _learningTip = '저녁에는 실습이나 문제 풀이를 해보세요';
    } else {
      _learningTip = '늦은 시간에는 가벼운 복습만 하세요';
    }

    // 날짜별로 다른 동기부여 메시지
    final tipIndex = dayOfYear % _learningTips.length;
    final motivationIndex = dayOfYear % _motivations.length;
    
    _learningTip = _learningTips[tipIndex];
    _motivationMessage = _motivations[motivationIndex];

    // 요일별 특별 메시지
    final weekday = now.weekday;
    if (weekday == 1) { // 월요일
      _motivationMessage = '새로운 한 주를 학습으로 시작해보세요!';
    } else if (weekday == 5) { // 금요일
      _motivationMessage = '이번 주 학습 내용을 정리해보세요';
    } else if (weekday == 6 || weekday == 7) { // 주말
      _learningTip = '주말에는 흥미로운 주제로 학습해보세요';
      _motivationMessage = '주말도 학습의 기회입니다!';
    }
  }

  // 채팅 화면 표시
  void _showChatScreen() {
    // ChatProvider 초기화
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.clearMessages();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.school,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '학습 AI 비서',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // AI 채팅 화면
              Expanded(
                child: ChatScreen(
                  initialEvent: null,
                  initialTopic: '학습',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _showChatScreen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade300, Colors.teal.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  '학습 도우미',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.lightbulb,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              _learningTip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _motivationMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '📚 오늘도 학습하세요!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
