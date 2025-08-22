import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLon != null) {
      _currentLatLng = LatLng(widget.initialLat!, widget.initialLon!);
      _address = widget.initialAddress ?? '';
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
      _address = ''; // 기기 위치 사용시 주소는 따로 설정되지 않음
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_currentLatLng!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위치 지도')),
      body: _currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLatLng!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) => _mapController = controller,
              markers: {
                Marker(
                  markerId: const MarkerId('me'),
                  position: _currentLatLng!,
                  infoWindow: InfoWindow(title: _address.isNotEmpty ? _address : '위치'),
                ),
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
} 