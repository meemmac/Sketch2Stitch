import 'dart:math';
import 'package:flutter/material.dart';

/// A circular color picker.
///
/// • Full mode (`paletteColors == null`): a standard hue/saturation wheel
///   with a brightness slider underneath — use this for Hair Color.
/// • Palette mode (`paletteColors != null`): the ring is built ONLY from the
///   colors you pass in (interpolated around the circle), so the picker
///   can never leave that gamut. Use this for Skin Tone, passing your
///   existing fair→deep swatch list.
class ColorWheelPicker extends StatefulWidget {
  final Color initialColor;
  final List<Color>? paletteColors;
  final ValueChanged<Color> onColorSelected;

  const ColorWheelPicker({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
    this.paletteColors,
  });

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  static const double _size = 240;
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  bool get _isPalette => widget.paletteColors != null;

  Color get _currentColor =>
      _isPalette ? _paletteColorAt(_hsv.hue, _hsv.saturation) : _hsv.toColor();

  /// Maps the ring angle (0–360°) to a position in the palette list, and
  /// uses distance-from-center as a lighten/darken nudge within that color —
  /// so you only ever land on shades that stay close to your source palette.
  Color _paletteColorAt(double hueDeg, double sat) {
    final colors = widget.paletteColors!;
    if (colors.length < 2) return colors.first;
    final t = (hueDeg % 360) / 360;
    final scaled = t * (colors.length - 1);
    final i = scaled.floor().clamp(0, colors.length - 2);
    final localT = scaled - i;
    final base = Color.lerp(colors[i], colors[i + 1], localT)!;
    final hsl = HSLColor.fromColor(base);
    final lightness = (hsl.lightness + (sat - 0.5) * 0.3).clamp(0.05, 0.95);
    return hsl.withLightness(lightness).toColor();
  }

  void _handlePan(Offset localPos) {
    const radius = _size / 2;
    final center = const Offset(radius, radius);
    final d = localPos - center;
    final dist = d.distance.clamp(0, radius);
    var angle = atan2(d.dy, d.dx) * 180 / pi;
    if (angle < 0) angle += 360;
    setState(() => _hsv = _hsv.withHue(angle).withSaturation(dist / radius));
    widget.onColorSelected(_currentColor);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanUpdate: (d) => _handlePan(d.localPosition),
          onTapDown: (d) => _handlePan(d.localPosition),
          child: SizedBox(
            width: _size,
            height: _size,
            child: CustomPaint(
              painter: _WheelPainter(
                hsv: _hsv,
                paletteColors: widget.paletteColors,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (!_isPalette)
          Row(
            children: [
              const Icon(Icons.brightness_6_outlined,
                  size: 16, color: Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _hsv.value,
                  onChanged: (v) {
                    setState(() => _hsv = _hsv.withValue(v));
                    widget.onColorSelected(_currentColor);
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final HSVColor hsv;
  final List<Color>? paletteColors;
  _WheelPainter({required this.hsv, this.paletteColors});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: paletteColors != null
            ? [...paletteColors!, paletteColors!.first]
            : List.generate(
                13, (i) => HSVColor.fromAHSV(1, i * 30.0, 1, 1).toColor()),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ringPaint);

    // White-out toward the center so saturation/lightness reads visually.
    final fadePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fadePaint);

    // Thumb
    final angle = hsv.hue * pi / 180;
    final dist = hsv.saturation * radius;
    final pos = center + Offset(cos(angle), sin(angle)) * dist;
    canvas.drawCircle(
        pos, 9, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(
        pos,
        9,
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.hsv != hsv || oldDelegate.paletteColors != paletteColors;
}