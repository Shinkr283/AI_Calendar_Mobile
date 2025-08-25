import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/places_service.dart';
import 'location_picker.dart';

class EventForm extends StatefulWidget {
  final Event? initialEvent;
  final DateTime? selectedDate; // 선택된 날짜 추가
  final void Function(Event event, int alarmMinutesBefore) onSave;

  const EventForm({
    super.key,
    this.initialEvent,
    this.selectedDate, // 선택된 날짜 추가
    required this.onSave,
  });

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  late DateTime _startTime;
  late DateTime _endTime;
  String _location = '';
  PlaceDetails? _selectedPlace;
  int _alarmMinutesBefore = 10; // 기본값 10분 전
  final List<int> _alarmOptions = [0, 5, 10, 15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    final e = widget.initialEvent;
    _title = e?.title ?? '';
    _description = e?.description ?? '';
    
    // 🗓️ 선택된 날짜가 있으면 해당 날짜로 시작 시간 설정
    if (e != null) {
      // 기존 일정 수정 시에는 기존 시간 유지
      _startTime = e.startTime;
      _endTime = e.endTime;
    } else if (widget.selectedDate != null) {
      // 새 일정 추가 시 선택된 날짜의 현재 시간으로 설정
      final now = DateTime.now();
      _startTime = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
        now.hour,
        now.minute,
      );
      _endTime = _startTime.add(const Duration(hours: 1));
    } else {
      // 선택된 날짜가 없으면 현재 시간 사용
      _startTime = DateTime.now();
      _endTime = DateTime.now().add(const Duration(hours: 1));
    }
    
    _location = e?.location ?? '';
    _alarmMinutesBefore = e?.alarmMinutesBefore ?? 10; // 기존 일정의 알림 시간 복원

     // 🗺️ 저장된 좌표가 있다면 PlaceDetails 생성
    if (e?.locationLatitude != null && e?.locationLongitude != null && e!.location.isNotEmpty) {
      _selectedPlace = PlaceDetails(
        placeId: '',
        name: e.location,
        address: e.location,
        latitude: e.locationLatitude!,
        longitude: e.locationLongitude!,
        types: [],
      );
      print('📍 저장된 장소 복원: ${e.location} (${e.locationLatitude}, ${e.locationLongitude})');
    } else if (e?.location != null && e!.location.isNotEmpty) {
      // 좌표는 없지만 장소 이름이 있다면 검색해서 좌표 찾기
      _searchAndSetInitialPlace(e.location);
    }
    print('🔧 EventForm 초기화: 알림 시간 = $_alarmMinutesBefore분 전');
  }

  // 🔍 장소 이름으로 검색해서 좌표 찾기
  void _searchAndSetInitialPlace(String placeName) async {
    try {
      print('🔍 장소 검색 시작: $placeName');
      final places = await PlacesService.searchPlaces(placeName);
      if (places.isNotEmpty) {
        final place = places.first;
        setState(() {
          _selectedPlace = PlaceDetails(
            placeId: place.placeId,
            name: place.mainText,
            address: place.description,
            latitude: 0, // 검색 결과에는 좌표가 없으므로 상세 정보 필요
            longitude: 0,
            types: [],
          );
        });
        
        // Place Details로 정확한 좌표 가져오기
        final detailedPlace = await PlacesService.getPlaceDetails(place.placeId);
        if (detailedPlace != null && mounted) {
          setState(() {
            _selectedPlace = detailedPlace;
          });
          print('✅ 초기 장소 설정 완료: ${detailedPlace.name} (${detailedPlace.latitude}, ${detailedPlace.longitude})');
        }
      }
    } catch (e) {
      print('❌ 초기 장소 검색 실패: $e');
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime : _endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
    );
    if (time == null) return;
    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = dateTime;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = dateTime;
        if (_endTime.isBefore(_startTime)) {
          _startTime = _endTime.subtract(const Duration(hours: 1));
        }
      }
    });
  }

  void _pickLocation() async {
    final result = await Navigator.of(context).push<PlaceDetails>(
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          initialLocation: _location,
          initialPlace: _selectedPlace,
          onLocationSelected: (place) {
            setState(() {
              _selectedPlace = place;
              _location = place.name;
            });
          },
        ),
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedPlace = result;
        _location = result.name;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      final event = Event(
        id: widget.initialEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _title,
        description: _description,
        startTime: _startTime,
        endTime: _endTime,
        location: _location,
        locationLatitude: _selectedPlace?.latitude,
        locationLongitude: _selectedPlace?.longitude,
        isCompleted: false,
        alarmMinutesBefore: _alarmMinutesBefore,
        createdAt: widget.initialEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      print('📝 Event 생성: 알림 시간 = ${event.alarmMinutesBefore}분 전');
      widget.onSave(event, _alarmMinutesBefore);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _title,
              decoration: const InputDecoration(labelText: '제목'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
              onSaved: (v) => _title = v!.trim(),
            ),
            TextFormField(
              initialValue: _description,
              decoration: const InputDecoration(labelText: '설명'),
              onSaved: (v) => _description = v ?? '',
            ),
            const SizedBox(height: 8),
            // 장소 입력 필드
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '장소',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _location.isEmpty ? '장소를 선택하세요' : _location,
                            style: TextStyle(
                              color: _location.isEmpty ? Colors.grey.shade500 : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          // 세부 주소 표시 제거 - UI 크기 고정을 위해
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('시작: ${_startTime.year}-${_startTime.month.toString().padLeft(2, '0')}-${_startTime.day.toString().padLeft(2, '0')} ${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'),
                ),
                TextButton(
                  onPressed: () => _pickDateTime(isStart: true),
                  child: const Text('변경'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text('종료: ${_endTime.year}-${_endTime.month.toString().padLeft(2, '0')}-${_endTime.day.toString().padLeft(2, '0')} ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'),
                ),
                TextButton(
                  onPressed: () => _pickDateTime(isStart: false),
                  child: const Text('변경'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 카테고리 / 우선순위 UI 잠시 비활성화
            // 알림 시간 설정
            DropdownButtonFormField<int>(
              value: _alarmMinutesBefore,
              decoration: const InputDecoration(labelText: '알림 시간'),
              items: _alarmOptions
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m == 0 ? '알림 없음' : '$m분 전'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _alarmMinutesBefore = v ?? 10),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: Text(widget.initialEvent == null ? '추가' : '수정'),
            ),
          ],
        ),
      ),
    );
  }
}