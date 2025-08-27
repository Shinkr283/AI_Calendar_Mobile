import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/places_service.dart';
// PlaceSuggestion은 places_service.dart에 정의됨

class MapScreen extends StatefulWidget {
  /// 보여줄 초기 위치 좌표 (위치가 없으면 기기 현재 위치 사용)
  final double? initialLat;
  final double? initialLon;
  final String? initialAddress;
  const MapScreen({Key? key, this.initialLat, this.initialLon, this.initialAddress}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  String _address = '';
  
  // 🔍 검색 관련 상태
  final TextEditingController _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  PlaceSuggestion? _selectedPlace;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLon != null) {
      _currentLatLng = LatLng(widget.initialLat!, widget.initialLon!);
      _address = widget.initialAddress ?? '';
    } else {
      // GPS 위치 획득 시도 (실패해도 기본 위치 사용)
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('위치 권한이 거부되었습니다.');
          // 권한이 거부되어도 기본 위치 사용
          if (mounted) {
            setState(() {
              _currentLatLng = const LatLng(37.5665, 126.9780); // 서울 기본 위치
            });
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('위치 권한이 영구적으로 거부되었습니다.');
        // 권한이 영구 거부되어도 기본 위치 사용
        if (mounted) {
          setState(() {
            _currentLatLng = const LatLng(37.5665, 126.9780); // 서울 기본 위치
          });
        }
        return;
      }
      
      // 위치 획득 시도
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // 10초 타임아웃
      );
      
      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(position.latitude, position.longitude);
          _address = ''; // 기기 위치 사용시 주소는 따로 설정되지 않음
        });
        
        // 지도 컨트롤러가 준비되면 이동
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLatLng!),
        );
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      // 실패 시 기본 위치 사용
      if (mounted) {
        setState(() {
          _currentLatLng = const LatLng(37.5665, 126.9780); // 서울 기본 위치
        });
      }
    }
  }

  // 🔍 장소 검색 (디바운싱 적용)
  void _searchPlaces(String query) {
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  // 🌐 실제 검색 수행
  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<PlaceSuggestion> suggestions = [];
      
      if (query.length > 2) { // 3글자 이상일 때만 API 호출
        suggestions = await PlacesService.searchPlaces(query);
        print('🔍 검색 결과: ${suggestions.length}개');
      }
      
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
      print('검색 오류: $e');
    }
  }

  // 📍 장소 선택 시 지도 이동
  Future<void> _selectPlace(PlaceSuggestion place) async {
    try {
      // Place Details API를 호출해서 좌표 정보 가져오기
      final placeDetails = await PlacesService.getPlaceDetails(place.placeId);
      
      if (placeDetails != null) {
        setState(() {
          _selectedPlace = place;
          _currentLatLng = LatLng(placeDetails.latitude, placeDetails.longitude);
          _address = placeDetails.address;
          _suggestions = [];
          _searchController.text = placeDetails.name;
        });
        
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(placeDetails.latitude, placeDetails.longitude),
            16.0,
          ),
        );
      } else {
        // placeDetails가 null인 경우
        print('장소 세부정보가 null입니다.');
        setState(() {
          _selectedPlace = place;
          _suggestions = [];
          _searchController.text = place.mainText;
        });
      }
    } catch (e) {
      print('장소 세부정보 가져오기 실패: $e');
      // 실패 시 기본 동작
      setState(() {
        _selectedPlace = place;
        _suggestions = [];
        _searchController.text = place.mainText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위치 지도')),
      body: _currentLatLng == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('위치 정보를 가져오는 중...'),
                ],
              ),
            )
          : Stack(
              children: [
                // 🗺️ 전체 화면 지도
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // 기본 버튼 비활성화
                  onMapCreated: (controller) => _mapController = controller,
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _currentLatLng!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: InfoWindow(
                        title: _selectedPlace?.mainText ?? '선택된 위치',
                        snippet: _address.isNotEmpty ? _address : '위치',
                      ),
                    ),
                  },
                  zoomControlsEnabled: false, // 기본 확대/축소 컨트롤 비활성화
                  mapType: MapType.normal,
                  compassEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  mapToolbarEnabled: true,
                  trafficEnabled: false,
                  indoorViewEnabled: false,
                  buildingsEnabled: true,
                ),
                
                // 🔍 커스텀 확대/축소 컨트롤
                Positioned(
                  right: 16,
                  bottom: 80, // 우하단에 위치
                  child: Column(
                    children: [
                      // 확대 버튼
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue),
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.zoomIn(),
                            );
                          },
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 축소 버튼
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.remove, color: Colors.blue),
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.zoomOut(),
                            );
                          },
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 🔍 상단 검색 바
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: _searchPlaces,
                                decoration: const InputDecoration(
                                  hintText: '장소를 검색하세요...',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (_isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            if (_searchController.text.isNotEmpty && !_isLoading)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _suggestions = [];
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      
                      // 🔍 검색 결과 목록
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _suggestions.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on, color: Colors.red, size: 20),
                                title: Text(
                                  suggestion.mainText,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  suggestion.secondaryText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectPlace(suggestion),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // 📍 검색 바 오른쪽 아래 내 위치 버튼
                Positioned(
                  right: 16,
                  top: 80, // 검색 바 아래에 위치
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.blue),
                      onPressed: () async {
                        try {
                          Position position = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high
                          );
                          final newLocation = LatLng(position.latitude, position.longitude);
                          
                          setState(() {
                            _currentLatLng = newLocation;
                            _address = '';
                            _selectedPlace = null;
                            _searchController.text = '';
                            _suggestions = [];
                          });
                          
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(newLocation, 15.0),
                          );
                        } catch (e) {
                          print('현재 위치 가져오기 실패: $e');
                        }
                      },
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 