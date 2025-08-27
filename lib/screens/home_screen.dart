import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';
import '../services/event_service.dart';
import '../services/chat_briefing_service.dart';
import '../services/user_service.dart';
import '../models/event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final EventService _eventService = EventService();
  final BriefingService _briefingService = BriefingService();
  final UserService _userService = UserService();
  
  Map<String, dynamic>? _weatherData;
  List<Event> _todayEvents = [];
  String? _aiRecommendation;
  bool _isLoading = true;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 정보 로드 (MBTI 가져오기)
      await _loadUserInfo();
      
      // 날씨 정보 로드 (빠른 로딩)
      _loadWeatherData();
      
      // 오늘 일정 로드 (빠른 로딩)
      _loadTodayEvents();
      
    } catch (e) {
      print('홈 데이터 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    
    // AI 추천은 별도로 비동기 로드 (화면이 먼저 표시된 후)
    _loadAiRecommendation();
  }

  Future<void> _loadUserInfo() async {
    try {
      var user = await _userService.getCurrentUser();
      
      // 앱 최초 실행 시 사용자가 없으면 기본 사용자를 생성
      user ??= await _userService.createUser(
        name: '사용자',
        email: 'user@example.com',
        mbtiType: 'INFP',
      );
      
      // MBTI는 BriefingService에서 직접 처리
    } catch (e) {
      print('사용자 정보 로드 실패: $e');
    }
  }

  Future<void> _loadWeatherData() async {
    try {
      final weather = await _weatherService.fetchCurrentLocationWeather();
      if (mounted) {
        setState(() {
          _weatherData = weather;
        });
      }
    } catch (e) {
      print('날씨 정보 로드 실패: $e');
    }
  }

  Future<void> _loadTodayEvents() async {
    try {
      final today = DateTime.now();
      final events = await _eventService.getEventsForDate(today);
      if (mounted) {
        setState(() {
          _todayEvents = events;
        });
      }
    } catch (e) {
      print('오늘 일정 로드 실패: $e');
    }
  }

  Future<void> _loadAiRecommendation() async {
    if (!mounted) return;
    setState(() => _isAiLoading = true);
    try {
      final today = DateTime.now();
      // ChatBriefingService에서 브리핑 내용 가져오기
      final recommendation = await _briefingService.getBriefingForDate(today);
      if (mounted) setState(() => _aiRecommendation = recommendation);
    } catch (e) {
      print('AI 추천 로드 실패: $e');
      if (mounted) setState(() => _aiRecommendation = 'AI 추천을 불러오는 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }
  // _buildSimplePrompt 제거 (ChatBriefingService 사용)

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '좋은 아침이에요!';
    if (hour < 18) return '좋은 오후에요!';
    return '좋은 저녁이에요!';
  }

  Widget _buildWeatherCard() {
    if (_weatherData == null) {
      return _buildLoadingCard('날씨 정보를 불러오는 중...');
    }

    final temp = _weatherData!['main']?['temp']?.toString() ?? 'N/A';
    final description = _weatherData!['weather']?[0]?['description'] ?? '날씨 정보 없음';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 날씨 아이콘 (텍스트로 대체)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.wb_sunny,
                size: 30,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 날씨',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$temp°C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayEventsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 일정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_todayEvents.length}개',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_todayEvents.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '오늘은 일정이 없어요!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ..._todayEvents.take(3).map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            if (_todayEvents.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '그 외 ${_todayEvents.length - 3}개 일정 더...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiRecommendationCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'AI 비서 추천',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isAiLoading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI 분석 중...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_aiRecommendation == null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI가 오늘 일정을 분석하고 있습니다...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                _aiRecommendation!,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(String message) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
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
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 헤더
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 날씨 카드
                    _buildWeatherCard(),
                    
                    // 오늘 일정 카드
                    _buildTodayEventsCard(),
                    
                    // AI 추천 카드
                    _buildAiRecommendationCard(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
