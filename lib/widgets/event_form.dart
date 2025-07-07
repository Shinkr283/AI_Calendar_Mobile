import 'package:flutter/material.dart';
import '../models/event.dart';

class EventForm extends StatefulWidget {
  final Event? initialEvent;
  final void Function(Event event) onSave;

  const EventForm({
    super.key,
    this.initialEvent,
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
  late String _category;
  late int _priority;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEvent;
    _title = e?.title ?? '';
    _description = e?.description ?? '';
    _startTime = e?.startTime ?? DateTime.now();
    _endTime = e?.endTime ?? DateTime.now().add(const Duration(hours: 1));
    _category = e?.category ?? EventCategory.personal;
    _priority = e?.priority ?? EventPriority.medium;
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

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      final event = Event(
        id: widget.initialEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _title,
        description: _description,
        startTime: _startTime,
        endTime: _endTime,
        location: '',
        category: _category,
        priority: _priority,
        isAllDay: false,
        recurrenceRule: null,
        attendees: [],
        color: '#2196F3',
        isCompleted: false,
        createdAt: widget.initialEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.onSave(event);
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
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: '카테고리'),
              items: EventCategory.all
                  .map((c) => DropdownMenuItem(value: c, child: Text(EventCategory.getDisplayName(c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? EventCategory.personal),
            ),
            DropdownButtonFormField<int>(
              value: _priority,
              decoration: const InputDecoration(labelText: '우선순위'),
              items: [
                DropdownMenuItem(value: EventPriority.low, child: Text('낮음')),
                DropdownMenuItem(value: EventPriority.medium, child: Text('보통')),
                DropdownMenuItem(value: EventPriority.high, child: Text('높음')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? EventPriority.medium),
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