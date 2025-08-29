import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/location_weather_service.dart';
import '../services/event_service.dart';
import '../services/chat_briefing_service.dart';
import '../services/chat_service.dart';
import '../models/event.dart';
import '../widgets/event_form.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationWeatherService _weatherService = LocationWeatherService();
  final EventService _eventService = EventService();
  final BriefingService _briefingService = BriefingService();
  
  Map<String, dynamic>? _weatherData;
  List<Event> _todayEvents = [];
  String? _aiRecommendation;
  String? _currentAddress;
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

  Future<void> _loadWeatherData() async {
    try {
      // 위치 정보와 날씨 정보를 함께 가져오기
      await _weatherService.updateAndSaveCurrentLocation();
      final weather = await _weatherService.fetchWeatherFromSavedLocation();
      final address = _weatherService.savedAddress;
      
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _currentAddress = address;
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '좋은 아침이에요!';
    if (hour < 18) return '좋은 오후에요!';
    return '좋은 저녁이에요!';
  }

  // 일정이 지났는지 확인하는 함수
  bool _isEventPast(Event event) {
    return event.endTime.isBefore(DateTime.now());
  }

  // 일정을 터치했을 때 AI와 대화 시작
  void _onEventTap(Event event) {
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
              // AI 채팅 화면
              Expanded(
                child: ChatScreen(
                  initialEvent: event,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 일정 편집 다이얼로그
  void _onEventEdit(Event event) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '일정 편집',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: EventForm(
                  initialEvent: event,
                  onSave: (updatedEvent, alarmMinutesBefore) async {
                    try {
                      await _eventService.updateEvent(updatedEvent);
                      await _loadTodayEvents(); // 일정 목록 새로고침
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('일정이 수정되었습니다.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('일정 수정 실패: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 일정 삭제 확인 다이얼로그
  void _onEventDelete(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('${event.title} 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _eventService.deleteEvent(event.id!);
                await _loadTodayEvents(); // 일정 목록 새로고침
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('일정이 삭제되었습니다.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('일정 삭제 실패: $e')),
                  );
                }
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherAndAiCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날씨 정보 섹션
            if (_weatherData != null) ...[
              Row(
                children: [
                  // 날씨 아이콘
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
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _currentAddress ?? '위치 정보 없음',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_weatherData!['main']?['temp']?.toString() ?? 'N/A'}°C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _weatherData!['weather']?[0]?['description'] ?? '날씨 정보 없음',
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
              const SizedBox(height: 20),
            ] else ...[
              // 날씨 로딩 상태
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.wb_sunny,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '날씨 정보를 불러오는 중...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            
            // AI 추천 섹션
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
            if (_aiRecommendation == null && !_isAiLoading)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI가 오늘 일정을 분석하고 있습니다...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else if (_aiRecommendation != null)
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
              ..._todayEvents.map((event) {
                final isPast = _isEventPast(event);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _onEventTap(event),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // 파란색 점 (이전 디자인)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isPast ? Colors.grey.shade400 : Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 일정 내용
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isPast ? Colors.grey.shade400 : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isPast ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 편집 버튼 (지난 일정이 아닌 경우에만 표시)
                          if (!isPast)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _onEventEdit(event);
                                } else if (value == 'delete') {
                                  _onEventDelete(event);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 16),
                                      SizedBox(width: 8),
                                      Text('수정'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('삭제', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
                    _buildWeatherAndAiCard(),
                    
                    // 오늘 일정 카드
                    _buildTodayEventsCard(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
