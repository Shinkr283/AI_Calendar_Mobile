import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/chat_screen.dart';
import '../services/chat_service.dart';

class StyleWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const StyleWidget({
    super.key,
    required this.isEnabled,
    this.onTap,
  });

  @override
  State<StyleWidget> createState() => _StyleWidgetState();
}

class _StyleWidgetState extends State<StyleWidget> {
  String _styleTip = '';
  String _fashionAdvice = '';

  final List<String> _styleTips = [
    '단순한 컬러 조합으로 세련된 룩을 완성하세요',
    '액세서리 하나로 포인트를 주세요',
    '계절에 맞는 소재를 선택하세요',
    '자신의 체형에 맞는 실루엣을 찾아보세요',
    '베이직 아이템으로 다양한 스타일링을 시도하세요',
    '컬러 톤을 맞춰 조화로운 룩을 만드세요',
    '신발 하나로 전체적인 분위기를 바꿔보세요',
    '레이어링으로 깊이 있는 스타일을 연출하세요',
  ];

  final List<String> _fashionAdvices = [
    '오늘은 모노톤 룩으로 깔끔하게',
    '파스텔 컬러로 부드러운 느낌을',
    '데님 아이템으로 캐주얼하게',
    '넥타이나 스카프로 포인트를',
    '화이트 아이템으로 시원하게',
    '블랙 베이스로 모던하게',
    '컬러풀한 액세서리로 생동감을',
    '미니멀한 디자인으로 심플하게',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      _generateStyleContent();
    }
  }

  @override
  void didUpdateWidget(StyleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _generateStyleContent();
    }
  }

  void _generateStyleContent() {
    if (!widget.isEnabled) return;

    final now = DateTime.now();
    final month = now.month;
    final hour = now.hour;
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    // 계절별 스타일 팁
    if (month >= 3 && month <= 5) { // 봄
      _styleTip = '봄에는 파스텔 컬러와 가벼운 소재를 활용하세요';
    } else if (month >= 6 && month <= 8) { // 여름
      _styleTip = '여름에는 시원한 소재와 밝은 컬러를 선택하세요';
    } else if (month >= 9 && month <= 11) { // 가을
      _styleTip = '가을에는 따뜻한 톤과 레이어링을 시도해보세요';
    } else { // 겨울
      _styleTip = '겨울에는 따뜻한 소재와 다크 컬러를 활용하세요';
    }

    // 시간대별 패션 조언
    if (hour >= 6 && hour < 10) {
      _fashionAdvice = '아침에는 편안하면서도 깔끔한 룩을';
    } else if (hour >= 10 && hour < 14) {
      _fashionAdvice = '점심 시간에는 비즈니스 캐주얼 룩을';
    } else if (hour >= 14 && hour < 18) {
      _fashionAdvice = '오후에는 활동적인 캐주얼 룩을';
    } else if (hour >= 18 && hour < 22) {
      _fashionAdvice = '저녁에는 세련된 룩으로 분위기를';
    } else {
      _fashionAdvice = '늦은 시간에는 편안한 홈웨어를';
    }

    // 날짜별로 다른 팁
    final tipIndex = dayOfYear % _styleTips.length;
    final adviceIndex = dayOfYear % _fashionAdvices.length;
    
    _styleTip = _styleTips[tipIndex];
    _fashionAdvice = _fashionAdvices[adviceIndex];

    // 요일별 특별 조언
    final weekday = now.weekday;
    if (weekday == 1) { // 월요일
      _fashionAdvice = '월요일에는 자신감을 주는 룩을 선택하세요';
    } else if (weekday == 5) { // 금요일
      _fashionAdvice = '금요일에는 주말을 기대하는 룩을';
    } else if (weekday == 6 || weekday == 7) { // 주말
      _styleTip = '주말에는 자유롭고 편안한 스타일을 즐기세요';
      _fashionAdvice = '주말에는 개성 있는 룩으로 즐거운 시간을';
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
                      Icons.checkroom,
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '스타일 AI 비서',
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
                  initialTopic: '스타일',
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
            colors: [Colors.pink.shade300, Colors.pink.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.3),
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
                  Icons.checkroom,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  '스타일 가이드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.style,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              _styleTip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _fashionAdvice,
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
                '👗 오늘도 스타일리시하게!',
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
