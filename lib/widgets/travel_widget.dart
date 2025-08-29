import 'package:flutter/material.dart';

class TravelWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const TravelWidget({
    super.key,
    required this.isEnabled,
    this.onTap,
  });

  @override
  State<TravelWidget> createState() => _TravelWidgetState();
}

class _TravelWidgetState extends State<TravelWidget> {
  String _travelTip = '';
  String _destinationSuggestion = '';

  final List<String> _travelTips = [
    '여행 전 체크리스트를 만들어보세요',
    '현지 음식을 꼭 맛보세요',
    '사진보다는 경험에 집중하세요',
    '여행 가방은 가볍게 준비하세요',
    '현지인과 대화해보세요',
    '예상치 못한 일정 변경에 유연하게 대처하세요',
    '여행 일기를 써보세요',
    '안전을 최우선으로 생각하세요',
  ];

  final List<String> _destinations = [
    '서울 근교의 힐링 장소',
    '전통 문화를 느낄 수 있는 곳',
    '자연 속에서 휴식을 취할 수 있는 곳',
    '맛집 투어가 가능한 지역',
    '역사적 의미가 있는 장소',
    '가족과 함께하기 좋은 곳',
    '혼자 여행하기 좋은 곳',
    '커플 여행에 추천하는 곳',
  ];

  final List<String> _seasonalDestinations = [
    '봄: 벚꽃 명소나 꽃 축제',
    '여름: 시원한 계곡이나 해변',
    '가을: 단풍 명소나 산행',
    '겨울: 온천이나 스키장',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      _generateTravelContent();
    }
  }

  @override
  void didUpdateWidget(TravelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _generateTravelContent();
    }
  }

  void _generateTravelContent() {
    if (!widget.isEnabled) return;

    final now = DateTime.now();
    final month = now.month;
    final weekday = now.weekday;
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    // 계절별 여행 팁
    if (month >= 3 && month <= 5) { // 봄
      _travelTip = '봄에는 벚꽃과 함께하는 여행을 계획해보세요';
    } else if (month >= 6 && month <= 8) { // 여름
      _travelTip = '여름에는 시원한 계곡이나 해변 여행을 추천합니다';
    } else if (month >= 9 && month <= 11) { // 가을
      _travelTip = '가을에는 단풍 구경과 함께하는 산행을 즐겨보세요';
    } else { // 겨울
      _travelTip = '겨울에는 온천이나 스키장에서 특별한 추억을 만드세요';
    }

    // 날짜별로 다른 추천지
    final tipIndex = dayOfYear % _travelTips.length;
    final destIndex = dayOfYear % _destinations.length;
    
    _travelTip = _travelTips[tipIndex];
    _destinationSuggestion = _destinations[destIndex];

    // 요일별 특별 추천
    if (weekday == 6 || weekday == 7) { // 주말
      _travelTip = '주말에는 가까운 곳으로 당일치기 여행을!';
      _destinationSuggestion = '서울 근교의 힐링 장소를 추천합니다';
    } else if (weekday == 1) { // 월요일
      _destinationSuggestion = '이번 주말을 위한 여행 계획을 세워보세요';
    } else if (weekday == 5) { // 금요일
      _travelTip = '금요일! 주말 여행 준비는 되셨나요?';
      _destinationSuggestion = '주말 여행을 위한 체크리스트를 확인하세요';
    }

    // 계절별 특별 추천
    if (month >= 3 && month <= 5) { // 봄
      _destinationSuggestion = _seasonalDestinations[0];
    } else if (month >= 6 && month <= 8) { // 여름
      _destinationSuggestion = _seasonalDestinations[1];
    } else if (month >= 9 && month <= 11) { // 가을
      _destinationSuggestion = _seasonalDestinations[2];
    } else { // 겨울
      _destinationSuggestion = _seasonalDestinations[3];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade300, Colors.green.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
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
                  Icons.flight,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '여행 가이드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.explore,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _travelTip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _destinationSuggestion,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '✈️ 새로운 모험을 떠나세요!',
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
