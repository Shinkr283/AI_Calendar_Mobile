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
    _getCurrentLocation();
    
    // 🎯 초기 장소 정보가 있다면 우선 사용
    if (widget.initialPlace != null) {
      _selectedPlace = widget.initialPlace!;
      _searchController.text = widget.initialPlace!.name;
      print('📍 초기 장소 설정: ${widget.initialPlace!.name}');
    } else if (widget.initialLocation != null) {
      // 초기 위치가 설정되어 있다면 검색 필드에 표시
      _searchController.text = widget.initialLocation!;
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

  // 🏷️ 장소 타입을 한국어로 변환
  String _getPlaceTypeDisplay(String type) {
    final typeMap = {
      'airport': '공항',
      'restaurant': '음식점',
      'hotel': '호텔',
      'hospital': '병원',
      'school': '학교',
      'university': '대학교',
      'bank': '은행',
      'gas_station': '주유소',
      'shopping_mall': '쇼핑몰',
      'subway_station': '지하철역',
      'bus_station': '버스정류장',
      'park': '공원',
      'tourist_attraction': '관광명소',
      'establishment': '시설',
      'point_of_interest': '관심장소',
      'premise': '건물',
      'political': '행정구역',
      'administrative_area_level_1': '시/도',
      'administrative_area_level_2': '시/군/구',
      'locality': '지역',
      'sublocality': '동네',
      'route': '도로',
    };
    
    return typeMap[type] ?? '장소';
  }

  // 🗺️ 지도 클릭 시 해당 위치 정보 가져오기
  void _onMapTap(LatLng position) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final placeDetails = await PlacesService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (placeDetails != null && mounted) {
        setState(() {
          _selectedPlace = placeDetails;
          _searchController.text = placeDetails.name;
          _suggestions = [];
        });

        // SnackBar 제거 - 불필요한 알림
      }
    } catch (e) {
      print('❌ 역방향 지오코딩 실패: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🎯 랜드마크 터치 시 실행되는 함수 (현재 버전에서는 onTap으로 대체)
  // void _onPoiTap(PointOfInterest poi) async {
  //   print('🏢 랜드마크 터치: ${poi.name} at ${poi.latLng.latitude}, ${poi.latLng.longitude}');
  //   // ... POI 처리 로직
  // }

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
              
              // 🗺️ 초기 장소가 있다면 즉시 이동 (지연 없음)
              if (widget.initialPlace != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(widget.initialPlace!.latitude, widget.initialPlace!.longitude), 
                    16.0
                  ),
                );
                print('📍 지도를 저장된 장소로 즉시 이동: ${widget.initialPlace!.name}');
              } else if (_selectedPlace != null) {
                // _selectedPlace가 있다면 해당 위치로 이동
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude), 
                    16.0
                  ),
                );
                print('📍 지도를 선택된 장소로 이동: ${_selectedPlace!.name}');
              } else if (_currentLocation != null) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
                  );
                });
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
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapType: MapType.normal,
            compassEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            mapToolbarEnabled: true,
            trafficEnabled: false,
            indoorViewEnabled: false,
            buildingsEnabled: true,
            onTap: _onMapTap,
            // onPoiTap: _onPoiTap, // 🎯 랜드마크 터치 기능 (현재 버전에서 지원하지 않음)
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
          
          // 🔽 Google Maps 스타일 드래그 가능한 하단 슬라이딩 패널
          if (_selectedPlace != null)
            DraggableScrollableSheet(
              initialChildSize: 0.3, // 초기 크기 (화면의 30%)
              minChildSize: 0.15,    // 최소 크기 (화면의 15%)
              maxChildSize: 0.6,     // 최대 크기 (화면의 60%)
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
              ),
              child: Column(
                    children: [
                      // 🔒 드래그 핸들 (항상 상단에 고정)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // 📋 스크롤 가능한 내용
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🏷️ 장소 타입 뱃지
                              if (_selectedPlace!.types.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _getPlaceTypeDisplay(_selectedPlace!.types.first),
                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              
                              const SizedBox(height: 12),
                              
                              // 📍 장소명과 평점
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                                          _selectedPlace!.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                  if (_selectedPlace!.rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                                              ...List.generate(5, (index) {
                                                return Icon(
                                                  index < (_selectedPlace!.rating! / 1).floor()
                                                      ? Icons.star
                                                      : index < (_selectedPlace!.rating! / 0.5).floor()
                                                          ? Icons.star_half
                                                          : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 18,
                                                );
                                              }),
                                              const SizedBox(width: 6),
                        Text(
                                                '${_selectedPlace!.rating!.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
                                  IconButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('"${_selectedPlace!.name}" 즐겨찾기에 추가'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.favorite_border),
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                              
            const SizedBox(height: 16),
                              
                              // 📍 주소
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 20, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedPlace!.address,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // 📞 전화번호
                              if (_selectedPlace!.phoneNumber != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 20, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedPlace!.phoneNumber!,
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('전화 앱으로 연결됩니다')),
                                        );
                                      },
                                      icon: const Icon(Icons.call, size: 20, color: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                              
                              // 🌐 웹사이트
                              if (_selectedPlace!.website != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.language, size: 20, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        '웹사이트 방문',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('웹 브라우저로 연결됩니다')),
                                        );
                                      },
                                      icon: const Icon(Icons.open_in_new, size: 20, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ],
                              
                              const SizedBox(height: 20),
                              
                              // 🛠️ 액션 버튼들
                              Row(
                                children: [
          Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('길찾기 앱으로 연결됩니다')),
                                        );
                                      },
                                      icon: const Icon(Icons.directions, size: 18),
                                      label: const Text('길찾기'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('장소 정보가 공유됩니다')),
                                        );
                                      },
                                      icon: const Icon(Icons.share, size: 18),
                                      label: const Text('공유'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // 🎯 확인 버튼 (패널 내부로 이동)
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _confirmLocation,
                                  icon: const Icon(Icons.check_circle, size: 20),
                                  label: Text(
                                    '"${_selectedPlace!.name}" 선택하기',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16), // 하단 여백
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}