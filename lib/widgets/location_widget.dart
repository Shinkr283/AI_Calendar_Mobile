import 'package:flutter/material.dart';
import '../services/location_weather_service.dart';

class LocationWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const LocationWidget({
    super.key,
    required this.isEnabled,
    this.onTap,
  });

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
      await locationService.updateAndSaveCurrentLocation();
      
      if (mounted) {
        setState(() {
          _currentAddress = locationService.currentAddress ?? '위치 정보 없음';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '위치 정보를 가져올 수 없습니다';
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
                Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '현재 위치',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
              Text(
                _currentAddress,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _getLocationAdvice(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
