import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A circular color picker, rendered once as a bitmap (not recomputed every
/// frame), so dragging is smooth even on lower-end devices.
///
/// • Full mode (`paletteColors == null`): standard hue wheel, radius =
///   saturation, plus a brightness slider. Use for Hair Color.
/// • Palette mode (`paletteColors != null`): the ring only ever produces
///   shades derived from the colors you pass in — angle blends between your
///   swatches (undertone), radius sweeps the FULL light→dark range within
///   that undertone (center = lightest, edge = deepest). Use for Skin Tone.
///
/// [onColorSelected] fires once per tap and once when a drag ends — never
/// continuously during a drag — so it's safe to call `setState` on a large
/// parent widget from the callback without causing jank.
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
  static const double _wheelSize = 260;
  static const int _res = 200; // bitmap resolution — computed once, not per frame

  double _angleDeg = 0;
  double _distFrac = 0;
  double _brightness = 1.0; // full-hue mode only
  Color _current = Colors.black;
  ui.Image? _wheelImage;

  bool get _isPalette => widget.paletteColors != null;

  @override
  void initState() {
    super.initState();
    _current = widget.initialColor;
    final hsv = HSVColor.fromColor(widget.initialColor);
    if (_isPalette) {
      final hsl = HSLColor.fromColor(widget.initialColor);
      // invert our center-light→edge-dark mapping to seed the thumb position
      _distFrac = ((0.88 - hsl.lightness) / 0.74).clamp(0.0, 1.0);
      _angleDeg = _closestPaletteAngle(widget.initialColor);
    } else {
      _angleDeg = hsv.hue;
      _distFrac = hsv.saturation;
      _brightness = hsv.value;
    }
    _generateWheelBitmap();
  }

  @override
  void dispose() {
    _wheelImage?.dispose();
    super.dispose();
  }

  double _closestPaletteAngle(Color target) {
    final colors = widget.paletteColors!;
    double bestAngle = 0;
    double bestDist = double.infinity;
    for (int a = 0; a < 360; a += 4) {
      final c = _paletteColorFor(a.toDouble(), 0.4);
      final d = (c.red - target.red).abs() +
          (c.green - target.green).abs() +
          (c.blue - target.blue).abs();
      if (d < bestDist) {
        bestDist = d.toDouble();
        bestAngle = a.toDouble();
      }
    }
    return bestAngle;
  }

  Color _paletteColorFor(double angleDeg, double distFrac) {
    final colors = widget.paletteColors!;
    final t = (angleDeg % 360) / 360;
    final scaled = t * colors.length;
    final i = scaled.floor() % colors.length;
    final j = (i + 1) % colors.length;
    final localT = scaled - scaled.floor();
    final base = Color.lerp(colors[i], colors[j], localT)!;
    final hsl = HSLColor.fromColor(base);
    // Center = lightest (≈0.88), edge = deepest (≈0.14) — full realistic range.
    final lightness = (0.88 - distFrac.clamp(0.0, 1.0) * 0.74).clamp(0.05, 0.95);
    return hsl.withLightness(lightness).toColor();
  }

  Color _colorForPolar(double angleDeg, double distFrac) {
    if (_isPalette) return _paletteColorFor(angleDeg, distFrac);
    return HSVColor.fromAHSV(1, angleDeg, distFrac.clamp(0.0, 1.0), 1).toColor();
  }

  Future<void> _generateWheelBitmap() async {
    final pixels = Uint8List(_res * _res * 4);
    final center = (_res - 1) / 2;
    for (int y = 0; y < _res; y++) {
      for (int x = 0; x < _res; x++) {
        final dx = x - center;
        final dy = y - center;
        final dist = sqrt(dx * dx + dy * dy) / center;
        final idx = (y * _res + x) * 4;
        if (dist > 1.0) continue; // leave transparent outside the circle
        var angle = atan2(dy, dx) * 180 / pi;
        if (angle < 0) angle += 360;
        final c = _colorForPolar(angle, dist);
        pixels[idx] = c.red;
        pixels[idx + 1] = c.green;
        pixels[idx + 2] = c.blue;
        pixels[idx + 3] = 255;
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _res,
      _res,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final img = await completer.future;
    if (mounted) setState(() => _wheelImage = img);
  }

  Color _currentColor() {
    final base = _colorForPolar(_angleDeg, _distFrac);
    if (_isPalette) return base;
    return HSVColor.fromColor(base).withValue(_brightness).toColor();
  }

  void _updateFromLocalPosition(Offset localPos, {required bool commit}) {
    const radius = _wheelSize / 2;
    const center = Offset(radius, radius);
    final d = localPos - center;
    final dist = (d.distance / radius).clamp(0.0, 1.0);
    var angle = atan2(d.dy, d.dx) * 180 / pi;
    if (angle < 0) angle += 360;
    setState(() {
      _angleDeg = angle;
      _distFrac = dist;
      _current = _currentColor();
    });
    if (commit) widget.onColorSelected(_current);
  }

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${_current.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Big, obvious live preview — not a tiny dot.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _current,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _current.withOpacity(0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              hex,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTapDown: (d) => _updateFromLocalPosition(d.localPosition, commit: true),
          onPanUpdate: (d) => _updateFromLocalPosition(d.localPosition, commit: false),
          onPanEnd: (_) => widget.onColorSelected(_current),
          child: SizedBox(
            width: _wheelSize,
            height: _wheelSize,
            child: _wheelImage == null
                ? const Center(child: CircularProgressIndicator())
                : CustomPaint(
                    painter: _WheelPainter(
                      image: _wheelImage!,
                      angleDeg: _angleDeg,
                      distFrac: _distFrac,
                    ),
                  ),
          ),
        ),
        if (_isPalette) ...[
          const SizedBox(height: 10),
          const Text(
            'Rotate for undertone · drag out from center for a deeper shade',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
        if (!_isPalette) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.brightness_6_outlined, size: 16, color: Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _brightness,
                  onChanged: (v) {
                    setState(() {
                      _brightness = v;
                      _current = _currentColor();
                    });
                  },
                  onChangeEnd: (_) => widget.onColorSelected(_current),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final ui.Image image;
  final double angleDeg;
  final double distFrac;
  _WheelPainter({required this.image, required this.angleDeg, required this.distFrac});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final angleRad = angleDeg * pi / 180;
    final pos = center + Offset(cos(angleRad), sin(angleRad)) * (distFrac * radius);

    canvas.drawCircle(pos, 11, Paint()..color = Colors.black26);
    canvas.drawCircle(pos, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      pos,
      9,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.angleDeg != angleDeg ||
      oldDelegate.distFrac != distFrac;
}