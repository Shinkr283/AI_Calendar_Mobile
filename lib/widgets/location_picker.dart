import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';

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
      print('📍 초기 장소 설정: ${widget.initialPlace!.name}');
    } else if (widget.initialLocation != null) {
      // 초기 위치가 설정되어 있다면 검색 필드에 표시
      _searchController.text = widget.initialLocation!;
    } else {
      // 🌍 새 일정 추가 시 - GPS 위치를 적극적으로 획득
      print('🎯 새 일정 추가 - GPS 위치 우선 획득 시작');
    }
    
    // GPS 위치는 항상 획득 (캐싱용)
    _getCurrentLocation();
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
      final position = await LocationService().getCurrentPosition();
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

  // 🎯 GPS 위치 또는 기본 위치로 지도 이동 (새 일정 추가 시)
  void _moveToCurrentLocationOrDefault(GoogleMapController controller) {
    if (_currentLocation != null) {
      // GPS 위치가 이미 있으면 즉시 이동
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
      );
      print('📍 지도를 현재 GPS 위치로 이동: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
    } else {
      // GPS 위치를 기다리면서 획득되면 이동
      print('📍 GPS 위치 대기 중... 획득되면 자동 이동');
      
      // GPS 위치 획득 후 지도 이동을 위한 타이머 설정
      Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (_currentLocation != null && mounted) {
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
          );
          print('📍 GPS 위치 획득 완료! 지도 이동: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
          timer.cancel();
        } else if (timer.tick > 25) { // 5초 후 타임아웃
          print('⏰ GPS 위치 획득 타임아웃 - 서울 기본 위치 사용');
          timer.cancel();
        }
      });
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

  // 장소 타입 변환 함수 제거됨 (상세 정보 표시 기능 제거됨)

  // 지도 터치 시 장소 정보 표시 기능 제거됨

  // 랜드마크 터치 기능 제거됨

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 선택'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 🗺️ 전체 화면 지도
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPlace != null
                  ? LatLng(widget.initialPlace!.latitude, widget.initialPlace!.longitude)
                  : _selectedPlace != null
                      ? LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude)
                      : _currentLocation ?? const LatLng(37.5665, 126.9780),
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              
              // 🗺️ 장소 우선순위: 기존 장소 > GPS 위치 > 기본 위치
              if (widget.initialPlace != null) {
                // 기존 일정 수정 시 - 저장된 장소로 즉시 이동
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(widget.initialPlace!.latitude, widget.initialPlace!.longitude), 
                    16.0
                  ),
                );
                print('📍 지도를 저장된 장소로 즉시 이동: ${widget.initialPlace!.name}');
              } else {
                // 새 일정 추가 시 - GPS 위치 우선 사용
                _moveToCurrentLocationOrDefault(controller);
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
                      infoWindow: InfoWindow(
                        title: _selectedPlace!.name,
                        snippet: _selectedPlace!.address,
                      ),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // 커스텀 버튼 사용
            zoomControlsEnabled: true,
            mapType: MapType.normal,
            compassEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            mapToolbarEnabled: true,
            trafficEnabled: false,
            indoorViewEnabled: false,
            buildingsEnabled: true,
            // 지도 터치 및 POI 터치 기능 제거됨
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
          
          // 📍 선택된 장소 간단 정보 (하단 고정)
          if (_selectedPlace != null)
            Positioned(
              bottom: 16,
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
          
          // 📍 우하단 내 위치 버튼
          Positioned(
            right: 16,
            bottom: 100, // 하단 선택 UI와 겹치지 않도록 여유 공간
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              onPressed: () async {
                if (_currentLocation != null && _mapController != null) {
                  await _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
                  );
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}