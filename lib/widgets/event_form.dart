import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/places_service.dart';
import 'location_picker.dart';
import 'color_picker.dart';

class EventForm extends StatefulWidget {
  final Event? initialEvent;
  final DateTime? selectedDate;
  final void Function(Event event, int alarmMinutesBefore) onSave;

  const EventForm({
    super.key,
    this.initialEvent,
    this.selectedDate,
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
  int _alarmMinutesBefore = 10;
  final List<int> _alarmOptions = [0, 5, 10, 15, 30, 60, 120];
  int _priority = 0;
  String _labelColor = '#FF0000';
  final List<Map<String, String>> _labelColorOptions = [
    {'value': '#FF0000', 'name': '빨간색', 'color': '#FF0000'},
    {'value': '#FF6B35', 'name': '주황색', 'color': '#FF6B35'},
    {'value': '#FFD700', 'name': '노란색', 'color': '#FFD700'},
    {'value': '#32CD32', 'name': '초록색', 'color': '#32CD32'},
    {'value': '#1E90FF', 'name': '파란색', 'color': '#1E90FF'},
    {'value': '#9370DB', 'name': '보라색', 'color': '#9370DB'},
    {'value': '#FF69B4', 'name': '분홍색', 'color': '#FF69B4'},
    {'value': '#8B4513', 'name': '갈색', 'color': '#8B4513'},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.initialEvent;
    _title = e?.title ?? '';
    _description = e?.description ?? '';
    
    if (e != null) {
      _startTime = e.startTime;
      _endTime = e.endTime;
    } else if (widget.selectedDate != null) {
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
      _startTime = DateTime.now();
      _endTime = DateTime.now().add(const Duration(hours: 1));
    }
    
    _location = e?.location ?? '';
    _alarmMinutesBefore = e?.alarmMinutesBefore ?? 10;
    _priority = e?.priority ?? 0;
    _labelColor = e?.labelColor ?? '#FF0000';

    if (e?.locationLatitude != null && e?.locationLongitude != null && e!.location.isNotEmpty) {
      _selectedPlace = PlaceDetails(
        placeId: '',
        name: e.location,
        address: e.location,
        latitude: e.locationLatitude!,
        longitude: e.locationLongitude!,
        types: [],
      );
    } else if (e?.location != null && e!.location.isNotEmpty) {
      _searchAndSetInitialPlace(e.location);
    }
  }

  Future<void> _searchAndSetInitialPlace(String placeName) async {
    try {
      final places = await PlacesService.searchPlaces(placeName);
      if (places.isNotEmpty) {
        final place = places.first;
        setState(() {
          _selectedPlace = PlaceDetails(
            placeId: place.placeId,
            name: place.mainText,
            address: place.description,
            latitude: 0,
            longitude: 0,
            types: [],
          );
        });
        
        final detailedPlace = await PlacesService.getPlaceDetails(place.placeId);
        if (detailedPlace != null && mounted) {
          setState(() {
            _selectedPlace = detailedPlace;
          });
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
    if (_selectedPlace == null && _location.isNotEmpty) {
      await _searchAndSetInitialPlace(_location);
    }
    
    if (_selectedPlace != null && _selectedPlace!.latitude == 0 && _selectedPlace!.longitude == 0 && _location.isNotEmpty) {
      await _searchAndSetInitialPlace(_location);
    }
    
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

  void _showColorPicker() async {
    final String? pickedColor = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('색상 선택'),
          content: SingleChildScrollView(
            child: ColorPicker(
              labelColor: _labelColor,
              onColorSelected: (color) {
                setState(() {
                  _labelColor = color;
                });
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop(_labelColor);
              },
            ),
          ],
        );
      },
    );

    if (pickedColor != null) {
      setState(() {
        _labelColor = pickedColor;
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
        priority: _priority,
        labelColor: _labelColor,
        createdAt: widget.initialEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
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
            // 우선순위 설정 (별 아이콘으로 선택)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '우선순위',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _priority = index + 1;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.star,
                          color: index < _priority ? Colors.amber : Colors.grey.shade300,
                          size: 30,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 라벨 색상 설정
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '라벨 색상',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._labelColorOptions.map((color) {
                        final isSelected = _labelColor == color['value'];
                        final colorValue = color['value']!;
                        final colorInt = int.parse(colorValue.substring(1), radix: 16);
                        print('색상 옵션: $colorValue -> $colorInt'); // 디버깅용
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _labelColor = colorValue;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Color(0xFF000000 + colorInt), // 알파값을 앞에 추가
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected ? Border.all(color: Colors.blue, width: 3) : Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              child: isSelected 
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                            ),
                          ),
                        );
                      }),
                      // RGB 직접 색상 커스터마이징
                      GestureDetector(
                        onTap: () => _showColorPicker(),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.indigo, Colors.purple],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: _labelColor.startsWith('#') && !_labelColorOptions.any((c) => c['value'] == _labelColor) 
                                ? Border.all(color: Colors.blue, width: 3) 
                                : null,
                            ),
                            child: const Icon(
                              Icons.color_lens,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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