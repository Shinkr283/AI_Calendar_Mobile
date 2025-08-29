import 'package:flutter/material.dart';

class ColorPicker extends StatefulWidget {
  final String labelColor;
  final Function(String) onColorSelected;

  const ColorPicker({
    super.key,
    required this.labelColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late double _red;
  late double _green;
  late double _blue;

  @override
  void initState() {
    super.initState();
    final color = Color(int.parse(widget.labelColor.substring(1), radix: 16));
    _red = color.red.toDouble();
    _green = color.green.toDouble();
    _blue = color.blue.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Color.fromARGB(255, _red.round(), _green.round(), _blue.round()),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 16),
        _buildColorSlider('빨강', _red, (value) {
          setState(() {
            _red = value;
          });
          _updateColor();
        }),
        _buildColorSlider('초록', _green, (value) {
          setState(() {
            _green = value;
          });
          _updateColor();
        }),
        _buildColorSlider('파랑', _blue, (value) {
          setState(() {
            _blue = value;
          });
          _updateColor();
        }),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('R: ${_red.round()}'),
            Text('G: ${_green.round()}'),
            Text('B: ${_blue.round()}'),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value,
          min: 0,
          max: 255,
          divisions: 255,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _updateColor() {
    final hexColor = '#${_red.round().toRadixString(16).padLeft(2, '0')}${_green.round().toRadixString(16).padLeft(2, '0')}${_blue.round().toRadixString(16).padLeft(2, '0')}';
    widget.onColorSelected(hexColor.toUpperCase());
  }
}
