import 'package:flutter/material.dart';

class HealthWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const HealthWidget({
    super.key,
    required this.isEnabled,
    this.onTap,
  });

  @override
  State<HealthWidget> createState() => _HealthWidgetState();
}

class _HealthWidgetState extends State<HealthWidget> {
  String _healthTip = '';
  String _exerciseRecommendation = '';

  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      _generateHealthContent();
    }
  }

  @override
  void didUpdateWidget(HealthWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _generateHealthContent();
    }
  }

  void _generateHealthContent() {
    if (!widget.isEnabled) return;

    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday;

    // 시간대별 건강 팁
    if (hour >= 6 && hour < 10) {
      _healthTip = '아침 운동으로 하루를 시작해보세요!';
      _exerciseRecommendation = '가벼운 스트레칭과 조깅을 추천합니다';
    } else if (hour >= 10 && hour < 14) {
      _healthTip = '점심 시간에 가벼운 산책을 해보세요';
      _exerciseRecommendation = '20분 정도의 산책이 좋습니다';
    } else if (hour >= 14 && hour < 18) {
      _healthTip = '오후에는 집중력 향상을 위한 운동을';
      _exerciseRecommendation = '요가나 필라테스를 추천합니다';
    } else if (hour >= 18 && hour < 22) {
      _healthTip = '저녁에는 스트레스 해소 운동을';
      _exerciseRecommendation = '가벼운 유산소 운동이 좋습니다';
    } else {
      _healthTip = '늦은 시간에는 휴식을 취하세요';
      _exerciseRecommendation = '가벼운 스트레칭만 하세요';
    }

    // 요일별 추가 팁
    if (weekday == 1) { // 월요일
      _healthTip += ' (새로운 한 주를 건강하게!)';
    } else if (weekday == 5) { // 금요일
      _healthTip += ' (주말을 위한 체력 관리!)';
    } else if (weekday == 6 || weekday == 7) { // 주말
      _healthTip = '주말에는 가족과 함께하는 운동을!';
      _exerciseRecommendation = '등산이나 자전거 타기를 추천합니다';
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
            colors: [Colors.red.shade300, Colors.red.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
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
                  Icons.favorite,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '건강 관리',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.fitness_center,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _healthTip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _exerciseRecommendation,
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
                '💪 건강한 하루 되세요!',
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
