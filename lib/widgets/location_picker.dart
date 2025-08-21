import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/places_service.dart';

class LocationPicker extends StatefulWidget {
  final String? initialLocation;
  final void Function(PlaceDetails place) onLocationSelected;

  const LocationPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  PlaceDetails? _selectedPlace;
  bool _isLoading = false;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _searchController.text = widget.initialLocation!;
      _searchPlaceByAddress(widget.initialLocation!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final suggestions = await PlacesService.searchPlaces(query);
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    }
  }

  void _searchPlaceByAddress(String address) async {
    setState(() {
      _isLoading = true;
    });

    final place = await PlacesService.geocodeAddress(address);
    if (mounted && place != null) {
      setState(() {
        _selectedPlace = place;
        _isLoading = false;
      });
      _updateMapLocation(place);
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectPlace(PlaceSuggestion suggestion) async {
    setState(() {
      _isLoading = true;
      _suggestions = [];
    });

    final placeDetails = await PlacesService.getPlaceDetails(suggestion.placeId);
    if (mounted && placeDetails != null) {
      setState(() {
        _selectedPlace = placeDetails;
        _searchController.text = placeDetails.name;
        _isLoading = false;
      });
      _updateMapLocation(placeDetails);
      widget.onLocationSelected(placeDetails);
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateMapLocation(PlaceDetails place) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.latitude, place.longitude),
          15.0,
        ),
      );
    }
  }

  void _addManualLocation() {
    final locationName = _searchController.text.trim();
    if (locationName.isNotEmpty) {
      // 수동으로 장소 정보 생성
      final manualPlace = PlaceDetails(
        placeId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        name: locationName,
        address: '$locationName (수동 입력)',
        latitude: 37.5665,  // 서울 기본 좌표
        longitude: 126.9780,
        types: ['manual'],
      );
      
      setState(() {
        _selectedPlace = manualPlace;
        _suggestions = [];
      });
      
      _updateMapLocation(manualPlace);
      
      // 사용자에게 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\"$locationName\" 장소가 추가되었습니다'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: '확인',
            textColor: Colors.white,
            onPressed: _confirmLocation,
          ),
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
        actions: [
          if (_selectedPlace != null)
            TextButton(
              onPressed: _confirmLocation,
              child: const Text(
                '확인',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 검색 입력 필드
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
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
                    ),
                  ),
                  onChanged: _searchPlaces,
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: Text(
                            suggestion.mainText,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(suggestion.secondaryText),
                          onTap: () => _selectPlace(suggestion),
                        );
                      },
                    ),
                  ),
                ] else if (_searchController.text.trim().isNotEmpty && !_isLoading) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Places API를 사용할 수 없습니다',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '결제 계정 설정이 필요합니다.\n수동으로 장소를 추가하시겠습니까?',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orange),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _addManualLocation(),
                          icon: const Icon(Icons.add_location),
                          label: Text('\"${_searchController.text.trim()}\" 수동 추가'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 선택된 장소 정보
          if (_selectedPlace != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPlace!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedPlace!.address,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  if (_selectedPlace!.phoneNumber != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _selectedPlace!.phoneNumber!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_selectedPlace!.rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedPlace!.rating!.toStringAsFixed(1)}점',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 지도
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedPlace != null
                        ? LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude)
                        : const LatLng(37.4219983, -122.084), // 기본 위치
                    zoom: _selectedPlace != null ? 15.0 : 10.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
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
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
