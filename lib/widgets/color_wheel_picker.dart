import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ── Local palette (kept in sync with the app's sage theme) ──────────────────
const _sage = Color(0xFF4E8B6F);
const _sageDark = Color(0xFF2C5C44);
const _ink = Color(0xFF1A2C22);

/// Opens the picker inside a polished, rounded modal card — drag handle,
/// header with a close button, and a full-width primary action.
Future<void> showColorWheelDialog({
  required BuildContext context,
  required String title,
  required Color initialColor,
  List<Color>? paletteColors,
  required ValueChanged<Color> onColorSelected,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Transform.scale(
        scale: 0.94 + 0.06 * curved.value,
        child: Opacity(
          opacity: curved.value,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ColorWheelPicker(
                      initialColor: initialColor,
                      paletteColors: paletteColors,
                      onColorSelected: onColorSelected,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _sage,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Use this color',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Dispatches to the right picker UI:
/// • Full mode (`paletteColors == null`): a hue wheel + brightness slider.
///   Use for Hair Color.
/// • Palette mode (`paletteColors != null`): a rectangular strip — drag
///   horizontally to blend between your skin-tone swatches (undertone),
///   drag vertically for light → dark. Use for Skin Tone.
class ColorWheelPicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (paletteColors != null) {
      return _SkinTonePicker(
        initialColor: initialColor,
        paletteColors: paletteColors!,
        onColorSelected: onColorSelected,
      );
    }
    return _HueWheelPicker(
      initialColor: initialColor,
      onColorSelected: onColorSelected,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// HAIR COLOR — hue wheel
// ─────────────────────────────────────────────────────────────────────────

class _HueWheelPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _HueWheelPicker({required this.initialColor, required this.onColorSelected});

  @override
  State<_HueWheelPicker> createState() => _HueWheelPickerState();
}

class _HueWheelPickerState extends State<_HueWheelPicker> {
  static const double _wheelSize = 232;
  static const int _res = 320;

  double _angleDeg = 0;
  double _distFrac = 0;
  double _brightness = 1.0;
  Color _current = Colors.black;
  ui.Image? _wheelImage;

  @override
  void initState() {
    super.initState();
    _current = widget.initialColor;
    final hsv = HSVColor.fromColor(widget.initialColor);
    _angleDeg = hsv.hue;
    _distFrac = hsv.saturation;
    _brightness = hsv.value;
    _generateWheelBitmap();
  }

  @override
  void dispose() {
    _wheelImage?.dispose();
    super.dispose();
  }

  Color _colorForPolar(double angleDeg, double distFrac) {
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
        // Fill the full square — the circular mask is applied later by the
        // anti-aliased canvas clipPath, so there's only ever one (smooth)
        // circle edge instead of two mismatched ones fighting each other.
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
    ui.decodeImageFromPixels(pixels, _res, _res, ui.PixelFormat.rgba8888, completer.complete);
    final img = await completer.future;
    if (mounted) setState(() => _wheelImage = img);
  }

  Color _currentColor() {
    final base = _colorForPolar(_angleDeg, _distFrac);
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

  String get _hex =>
      '#${_current.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewPill(color: _current, hex: _hex),
        const SizedBox(height: 18),
        GestureDetector(
          onTapDown: (d) => _updateFromLocalPosition(d.localPosition, commit: true),
          onPanUpdate: (d) => _updateFromLocalPosition(d.localPosition, commit: false),
          onPanEnd: (_) => widget.onColorSelected(_current),
          child: Container(
            width: _wheelSize + 16,
            height: _wheelSize + 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              width: _wheelSize + 8,
              height: _wheelSize + 8,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: SizedBox(
                width: _wheelSize,
                height: _wheelSize,
                child: _wheelImage == null
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: _sage),
                        ),
                      )
                    : CustomPaint(
                        painter: _WheelPainter(
                          image: _wheelImage!,
                          angleDeg: _angleDeg,
                          distFrac: _distFrac,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _BrightnessSlider(
          value: _brightness,
          hueColor: HSVColor.fromAHSV(1, _angleDeg, _distFrac.clamp(0.0, 1.0), 1).toColor(),
          onChanged: (v) {
            setState(() {
              _brightness = v;
              _current = _currentColor();
            });
          },
          onChangeEnd: () => widget.onColorSelected(_current),
        ),
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
    final clipPath = Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black.withOpacity(0.06),
    );

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final angleRad = angleDeg * pi / 180;
    final pos = center + Offset(cos(angleRad), sin(angleRad)) * (distFrac * radius);

    _drawThumb(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.angleDeg != angleDeg || oldDelegate.distFrac != distFrac;
}

// ─────────────────────────────────────────────────────────────────────────
// SKIN TONE — rectangular strip (x = undertone blend, y = light → dark)
// ─────────────────────────────────────────────────────────────────────────

class _SkinTonePicker extends StatefulWidget {
  final Color initialColor;
  final List<Color> paletteColors;
  final ValueChanged<Color> onColorSelected;

  const _SkinTonePicker({
    required this.initialColor,
    required this.paletteColors,
    required this.onColorSelected,
  });

  @override
  State<_SkinTonePicker> createState() => _SkinTonePickerState();
}

class _SkinTonePickerState extends State<_SkinTonePicker> {
  static const double _boxWidth = 264;
  static const double _boxHeight = 150;
  static const int _resX = 240;
  static const int _resY = 140;

  // Realistic skin-tone lightness band — never washes out to white,
  // never crushes to black, unlike the old wheel's 0.88 center.
  static const double _lightestL = 0.62;
  static const double _darkestL = 0.14;

  double _xFrac = 0.5; // undertone position, left → right across swatches
  double _yFrac = 0.35; // light (0, top) → dark (1, bottom)
  Color _current = Colors.black;
  ui.Image? _gradientImage;

  @override
  void initState() {
    super.initState();
    _current = widget.initialColor;
    final closest = _closestXY(widget.initialColor);
    _xFrac = closest.dx;
    _yFrac = closest.dy;
    _generateGradientBitmap();
  }

  @override
  void dispose() {
    _gradientImage?.dispose();
    super.dispose();
  }

  Color _colorForXY(double xFrac, double yFrac) {
    final colors = widget.paletteColors;
    if (colors.length == 1) {
      final hsl = HSLColor.fromColor(colors.first);
      final lightness =
          (_lightestL - yFrac.clamp(0.0, 1.0) * (_lightestL - _darkestL)).clamp(_darkestL, _lightestL);
      return hsl.withLightness(lightness).toColor();
    }
    final scaled = xFrac.clamp(0.0, 1.0) * (colors.length - 1);
    final i = scaled.floor().clamp(0, colors.length - 2);
    final localT = scaled - i;
    final base = Color.lerp(colors[i], colors[i + 1], localT)!;
    final hsl = HSLColor.fromColor(base);
    final lightness =
        (_lightestL - yFrac.clamp(0.0, 1.0) * (_lightestL - _darkestL)).clamp(_darkestL, _lightestL);
    return hsl.withLightness(lightness).toColor();
  }

  Offset _closestXY(Color target) {
    double bestX = 0.5, bestY = 0.5, bestDist = double.infinity;
    for (int yi = 0; yi <= 20; yi++) {
      final y = yi / 20;
      for (int xi = 0; xi <= 20; xi++) {
        final x = xi / 20;
        final c = _colorForXY(x, y);
        final d = (c.red - target.red).abs() +
            (c.green - target.green).abs() +
            (c.blue - target.blue).abs();
        if (d < bestDist) {
          bestDist = d.toDouble();
          bestX = x;
          bestY = y;
        }
      }
    }
    return Offset(bestX, bestY);
  }

  Future<void> _generateGradientBitmap() async {
    final pixels = Uint8List(_resX * _resY * 4);
    for (int y = 0; y < _resY; y++) {
      final yFrac = y / (_resY - 1);
      for (int x = 0; x < _resX; x++) {
        final xFrac = x / (_resX - 1);
        final idx = (y * _resX + x) * 4;
        final c = _colorForXY(xFrac, yFrac);
        pixels[idx] = c.red;
        pixels[idx + 1] = c.green;
        pixels[idx + 2] = c.blue;
        pixels[idx + 3] = 255;
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, _resX, _resY, ui.PixelFormat.rgba8888, completer.complete);
    final img = await completer.future;
    if (mounted) setState(() => _gradientImage = img);
  }

  void _updateFromLocalPosition(Offset localPos, {required bool commit}) {
    final xFrac = (localPos.dx / _boxWidth).clamp(0.0, 1.0);
    final yFrac = (localPos.dy / _boxHeight).clamp(0.0, 1.0);
    setState(() {
      _xFrac = xFrac;
      _yFrac = yFrac;
      _current = _colorForXY(_xFrac, _yFrac);
    });
    if (commit) widget.onColorSelected(_current);
  }

  String get _hex =>
      '#${_current.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewPill(color: _current, hex: _hex),
        const SizedBox(height: 18),
        GestureDetector(
          onTapDown: (d) => _updateFromLocalPosition(d.localPosition, commit: true),
          onPanUpdate: (d) => _updateFromLocalPosition(d.localPosition, commit: false),
          onPanEnd: (_) => widget.onColorSelected(_current),
          child: Container(
            width: _boxWidth,
            height: _boxHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _gradientImage == null
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: _sage),
                      ),
                    )
                  : CustomPaint(
                      painter: _RectPainter(
                        image: _gradientImage!,
                        xFrac: _xFrac,
                        yFrac: _yFrac,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Drag sideways for undertone · up and down for light to dark',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.black38, height: 1.3),
        ),
      ],
    );
  }
}

class _RectPainter extends CustomPainter {
  final ui.Image image;
  final double xFrac;
  final double yFrac;
  _RectPainter({required this.image, required this.xFrac, required this.yFrac});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(18),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black.withOpacity(0.06),
    );

    final pos = Offset(xFrac * size.width, yFrac * size.height);
    _drawThumb(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _RectPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.xFrac != xFrac || oldDelegate.yFrac != yFrac;
}

// ─────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────

/// Shared thumb drawing used by both painters — small white disc with a
/// soft shadow and sage-colored core, so selection is always legible
/// against any underlying color.
void _drawThumb(Canvas canvas, Offset pos) {
  canvas.drawCircle(pos, 13, Paint()..color = Colors.black.withOpacity(0.15));
  canvas.drawCircle(pos, 10, Paint()..color = Colors.white);
  canvas.drawCircle(
    pos,
    10,
    Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  canvas.drawCircle(pos, 5.5, Paint()..color = _sageDark.withOpacity(0.85));
}

class _PreviewPill extends StatelessWidget {
  final Color color;
  final String hex;
  const _PreviewPill({required this.color, required this.hex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE3EBE6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.45), blurRadius: 8, spreadRadius: 0.5),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            hex,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrightnessSlider extends StatelessWidget {
  final double value; // 0..1
  final Color hueColor;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  const _BrightnessSlider({
    required this.value,
    required this.hueColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final thumbX = (value.clamp(0.0, 1.0)) * trackWidth;
        return SizedBox(
          height: 30,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(colors: [Colors.black, hueColor]),
                ),
              ),
              Positioned(
                left: (thumbX - 12).clamp(0.0, trackWidth - 24),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (d) => onChanged((d.localPosition.dx / trackWidth).clamp(0.0, 1.0)),
                  onPanUpdate: (d) => onChanged((d.localPosition.dx / trackWidth).clamp(0.0, 1.0)),
                  onPanEnd: (_) => onChangeEnd(),
                  onTapUp: (_) => onChangeEnd(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}