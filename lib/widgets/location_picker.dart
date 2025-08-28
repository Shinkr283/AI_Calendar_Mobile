import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/places_service.dart';
import '../services/location_weather_service.dart';

class LocationPicker extends StatefulWidget {
  final Function(PlaceDetails) onLocationSelected;
  final String? initialLocation;
  final PlaceDetails? initialPlace; // 초기 장소 정보 추가

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
    this.initialPlace,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  GoogleMapController? _mapController;
  PlaceDetails? _selectedPlace;
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    
    // 🎯 초기 장소 정보가 있다면 우선 사용
    if (widget.initialPlace != null) {
      _selectedPlace = widget.initialPlace!;
      _searchController.text = widget.initialPlace!.name;
      print('📍 초기 장소 설정: ${widget.initialPlace!.name} (${widget.initialPlace!.latitude}, ${widget.initialPlace!.longitude})');
    } else if (widget.initialLocation != null) {
      // 초기 위치가 설정되어 있다면 검색 필드에 표시
      _searchController.text = widget.initialLocation!;
      print('📍 초기 위치 텍스트 설정: $widget.initialLocation');
    } else {
      // 🌍 새 일정 추가 시 - GPS 위치를 적극적으로 획득
      print('🎯 새 일정 추가 - GPS 위치 우선 획득 시작');
    }
    
    // GPS 위치를 즉시 획득하고 지도 초기화 (새 일정 추가 시에만)
    if (widget.initialPlace == null) {
      _getCurrentLocationAndInitializeMap();
    } else {
      print('📍 기존 장소가 있으므로 GPS 위치 획득 건너뜀');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // 🌍 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await LocationWeatherService().getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        print('📍 현재 위치 획득: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
      print('❌ 현재 위치 획득 실패: $e');
    }
  }

  // 🌍 GPS 위치 획득 및 지도 초기화 (map_screen.dart와 완전히 동일한 로직)
  Future<void> _getCurrentLocationAndInitializeMap() async {
    // 🚫 기존 장소가 있으면 GPS 위치 획득 건너뛰기
    if (widget.initialPlace != null) {
      print('📍 기존 장소가 있으므로 GPS 위치 획득 건너뜀');
      return;
    }
    
    try {
      print('📍 GPS 위치 획득 시작...');
      
      // 위치 권한 확인 (map_screen.dart와 동일)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('위치 권한이 거부되었습니다.');
          // 권한이 거부되어도 기본 위치 사용
          if (mounted) {
            setState(() {
              _currentLocation = const LatLng(37.5665, 126.9780); // 서울 기본 위치
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
            _currentLocation = const LatLng(37.5665, 126.9780); // 서울 기본 위치
          });
        }
        return;
      }
      
      // 위치 획득 시도 (map_screen.dart와 완전히 동일)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // 10초 타임아웃
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        print('📍 GPS 위치 획득 완료: ${position.latitude}, ${position.longitude}');
        
        // 지도 컨트롤러가 준비되면 이동 (map_screen.dart와 동일)
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation!),
        );
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      // 실패 시 기본 위치 사용 (map_screen.dart와 동일)
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(37.5665, 126.9780); // 서울 기본 위치
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
        print('🔍 온라인 API 결과: ${suggestions.length}개');
      }
      
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
        print('🔄 UI 업데이트 완료: ${suggestions.length}개 표시');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
      print('❌ 장소 검색 오류: $e');
    }
  }

  // 📍 장소 선택
  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    try {
      final placeDetails = await PlacesService.getPlaceDetails(suggestion.placeId);
      
      if (placeDetails != null) {
        setState(() {
          _selectedPlace = placeDetails;
          _searchController.text = placeDetails.name;
          _suggestions = [];
        });

        // 지도 카메라를 선택된 장소로 이동
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(placeDetails.latitude, placeDetails.longitude),
              15.0,
            ),
          );
        }

        print('✅ 장소 선택 완료: ${placeDetails.name}');
      }
    } catch (e) {
      print('❌ 장소 세부정보 가져오기 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('장소 정보를 가져올 수 없습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 📍 수동 위치 추가
  void _addManualLocation() {
    final locationName = _searchController.text.trim();
    if (locationName.isNotEmpty && _currentLocation != null) {
      final manualPlace = PlaceDetails(
        placeId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        name: locationName,
        address: '수동 추가된 위치',
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        types: ['manual_location'],
        phoneNumber: null,
        website: null,
        rating: null,
      );
      
      setState(() {
        _selectedPlace = manualPlace;
        _suggestions = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$locationName" 장소가 추가되었습니다'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmLocation() {
    if (_selectedPlace != null) {
      widget.onLocationSelected(_selectedPlace!);
      Navigator.of(context).pop(_selectedPlace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 선택'),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 🎯 초기 장소가 있으면 바로 지도 표시 (기존 일정 수정 시)
    if (widget.initialPlace != null) {
      print('📍 기존 장소로 지도 표시: ${widget.initialPlace!.name}');
      return _buildMap();
    }
    
    // 🌍 새 일정 추가 시 - GPS 위치가 준비될 때까지 로딩 UI 표시
    if (_currentLocation == null) {
      print('📍 GPS 위치 대기 중... 로딩 UI 표시');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('현재 위치를 가져오는 중...'),
          ],
        ),
      );
    }
    
    // 📍 GPS 위치가 준비되면 지도 표시 (새 일정 추가 시)
    print('📍 GPS 위치로 지도 표시: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
    return _buildMap();
  }

  Widget _buildMap() {
    return Stack(
      children: [
        // 🗺️ 전체 화면 지도
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialPlace != null
                ? LatLng(widget.initialPlace!.latitude, widget.initialPlace!.longitude)
                : _selectedPlace != null
                    ? LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude)
                    : _currentLocation ?? const LatLng(37.5665, 126.9780), // 안전한 폴백
            zoom: widget.initialPlace != null ? 16.0 : 15.0, // 기존 장소는 더 확대
          ),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            
            // 🗺️ 장소 우선순위: 기존 장소 > GPS 위치 (map_screen.dart와 동일한 로직)
            if (widget.initialPlace != null) {
              // 기존 일정 수정 시 - 저장된 장소로 즉시 이동
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(widget.initialPlace!.latitude, widget.initialPlace!.longitude), 
                  16.0
                ),
              );
              print('📍 지도를 저장된 장소로 즉시 이동: ${widget.initialPlace!.name} (${widget.initialPlace!.latitude}, ${widget.initialPlace!.longitude})');
            } else if (_currentLocation != null) {
              // 새 일정 추가 시 - GPS 위치로 즉시 이동 (map_screen.dart와 동일)
              controller.animateCamera(
                CameraUpdate.newLatLng(_currentLocation!),
              );
              print('📍 지도를 GPS 위치로 즉시 이동: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
            }
          },
          markers: _selectedPlace != null
              ? {
                  Marker(
                    markerId: const MarkerId('selected_place'),
                    position: LatLng(
                      _selectedPlace!.latitude,
                      _selectedPlace!.longitude,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: InfoWindow(
                      title: _selectedPlace!.name,
                      snippet: _selectedPlace!.address,
                    ),
                  ),
                }
              : {},
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // 커스텀 버튼 사용
          zoomControlsEnabled: false, // 기본 확대/축소 컨트롤 비활성화
          mapType: MapType.normal,
          compassEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          mapToolbarEnabled: true,
          trafficEnabled: false,
          indoorViewEnabled: false,
          buildingsEnabled: true,
          liteModeEnabled: false,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        ),
        
        // 🔍 상단 검색 바
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            children: [
              Container(
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
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '장소를 검색하세요',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    if (_selectedPlace != null && value == _selectedPlace!.name) {
                      return;
                    }
                    
                    if (_selectedPlace != null) {
                      setState(() {
                        _selectedPlace = null;
                      });
                    }
                    
                    _searchPlaces(value);
                  },
                  onTap: () {
                    if (_selectedPlace != null) {
                      _searchController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _searchController.text.length,
                      );
                    }
                  },
                ),
              ),
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
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _suggestions.length,
                    cacheExtent: 100,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectPlace(suggestion),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion.mainText,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        suggestion.secondaryText,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                if (_currentLocation != null && _mapController != null) {
                  await _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
                  );
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
        
        // 📍 선택된 장소 간단 정보 (하단 고정 - 확대/축소 컨트롤과 겹치지 않도록 조정)
        if (_selectedPlace != null)
          Positioned(
            bottom: 60, // 확대/축소 컨트롤 위에 위치하도록 조정
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPlace!.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedPlace!.address,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('이 장소 선택'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // 📍 우하단 내 위치 버튼 (새 일정 추가 시에만 표시)
        if (widget.initialPlace == null)
          Positioned(
            right: 16,
            bottom: _selectedPlace != null ? 140 : 80, // 카드가 있으면 위로, 없으면 아래로
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
                  if (_currentLocation != null && _mapController != null) {
                    await _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
                    );
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
        
        // 🔍 커스텀 확대/축소 컨트롤 (카드와 겹치지 않도록 동적 위치 조정)
        Positioned(
          right: 16,
          bottom: _selectedPlace != null ? 200 : 140, // 카드가 있으면 더 위로
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
      ],
    );
  }
}