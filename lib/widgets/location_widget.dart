import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_weather_service.dart';
import '../services/chat_service.dart';
import '../screens/chat_screen.dart';

class LocationWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const LocationWidget({super.key, required this.isEnabled, this.onTap});

  @override
  State<LocationWidget> createState() => _LocationWidgetState();
}

class _LocationWidgetState extends State<LocationWidget> {
  bool _isLoading = true;
  String _currentAddress = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      _loadLocationData();
    }
  }

  @override
  void didUpdateWidget(LocationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _loadLocationData();
    }
  }

  Future<void> _loadLocationData() async {
    if (!widget.isEnabled) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final locationService = LocationWeatherService();

      // 위치 업데이트 시도
      await locationService.updateAndSaveCurrentLocation();

      // 주소가 비어있으면 잠시 기다린 후 다시 확인
      String? address = locationService.savedAddress;
      if (address == null || address.isEmpty) {
        // 주소 변환이 비동기로 처리되므로 잠시 대기
        await Future.delayed(const Duration(seconds: 2));
        address = locationService.savedAddress;
      }

      if (mounted) {
        setState(() {
          _currentAddress = address ?? '위치 정보 없음';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ LocationWidget: 위치 정보 로드 실패 - $e');
      if (mounted) {
        setState(() {
          _errorMessage = '위치 정보를 가져올 수 없습니다: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _getLocationAdvice() {
    if (_currentAddress.isEmpty || _currentAddress == '위치 정보 없음') {
      return '위치 정보를 확인해보세요';
    }

    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 12) {
      return '좋은 아침입니다! 주변 카페를 찾아보세요';
    } else if (hour >= 12 && hour < 18) {
      return '점심 시간! 맛집을 추천해드릴까요?';
    } else if (hour >= 18 && hour < 22) {
      return '저녁 시간! 주변 식당을 확인해보세요';
    } else {
      return '늦은 시간입니다. 안전하게 이동하세요';
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
                      Icons.location_on,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '위치 AI 비서',
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
                  initialTopic: '위치',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 맛집 추천 채팅 화면 표시
  void _showRestaurantRecommendationChat() async {
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
                      Icons.restaurant,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '맛집 추천',
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
                  initialTopic: '위치',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 잠시 후 맛집 추천 자동 실행
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      // 현재 위치 정보가 있으면 맛집 추천 실행
      if (_currentAddress.isNotEmpty && _currentAddress != '위치 정보 없음') {
        await chatProvider.handleRestaurantRecommendationRequest('맛집 추천해줘');
      } else {
        // 위치 정보가 없으면 위치 업데이트 후 맛집 추천
        await _loadLocationData();
        await Future.delayed(const Duration(seconds: 1));
        if (_currentAddress.isNotEmpty && _currentAddress != '위치 정보 없음') {
          await chatProvider.handleRestaurantRecommendationRequest('맛집 추천해줘');
        } else {
          chatProvider.addAssistantText('위치 정보를 가져올 수 없어 맛집 추천이 어렵습니다. 위치 권한을 확인해주세요.');
        }
      }
    }
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
            colors: [Colors.blue.shade300, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
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
                Icon(Icons.location_on, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  _currentAddress.isNotEmpty && _currentAddress != '위치 정보 없음'
                      ? _currentAddress
                      : '현재 위치',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else ...[
                  // 맛집 추천 아이콘
                  IconButton(
                    icon: const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _showRestaurantRecommendationChat,
                    tooltip: '맛집 추천',
                  ),
                  // 위치 새로고침 아이콘
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _loadLocationData,
                    tooltip: '위치 새로고침',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            if (_isLoading)
              const Text(
                '위치 정보를 가져오는 중...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              )
            else if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              )
            else ...[
              const SizedBox(height: 7),
              Text(
                _getLocationAdvice(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
