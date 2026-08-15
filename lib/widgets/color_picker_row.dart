import 'package:flutter/material.dart';
import 'color_wheel_picker.dart';

/// A polished, self-contained color-selection row: named swatches, a wheel
/// launcher for anything else, a prominent live preview, and an always-visible
/// lighten/darken slider that appears the moment a color is picked — no
/// long-press required.
class ColorPickerRow extends StatelessWidget {
  final List<Color> swatches;
  final Color baseColor; // the swatch/wheel pick BEFORE lighten/darken
  final double adjustDelta; // -0.4..0.4
  final ValueChanged<Color> onBaseChanged;
  final ValueChanged<double> onAdjustChanged;
  final List<Color>? wheelPalette; // null = full hue wheel, else constrained
  final String wheelDialogTitle;
  final Color accent;
  final Color pale;
  final Color border;

  const ColorPickerRow({
    super.key,
    required this.swatches,
    required this.baseColor,
    required this.adjustDelta,
    required this.onBaseChanged,
    required this.onAdjustChanged,
    required this.wheelDialogTitle,
    required this.accent,
    required this.pale,
    required this.border,
    this.wheelPalette,
  });

  Color get _finalColor {
    final hsl = HSLColor.fromColor(baseColor);
    return hsl.withLightness((hsl.lightness + adjustDelta).clamp(0.0, 1.0)).toColor();
  }

  String get _hex {
    final c = _finalColor;
    return '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _openWheel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(wheelDialogTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: ColorWheelPicker(
          initialColor: baseColor,
          paletteColors: wheelPalette,
          onColorSelected: (c) {
            onBaseChanged(c);
            onAdjustChanged(0); // fresh pick starts from its own true shade
          },
        ),
        actionsPadding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pale,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Live preview header ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _finalColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _finalColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _hex,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _openWheel(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: wheelPalette != null
                              ? SweepGradient(colors: wheelPalette!)
                              : const SweepGradient(
                                  colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red],
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'More shades',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Named swatches ──────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: swatches.map((c) {
              final selected = c.value == baseColor.value;
              return GestureDetector(
                onTap: () {
                  onBaseChanged(c);
                  onAdjustChanged(0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? accent : Colors.black12,
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 6, spreadRadius: 0.5)]
                        : null,
                  ),
                  child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),

          // ── Always-visible lighten/darken ───────────────────────────
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: Color(0xFF2A2A2A), shape: BoxShape.circle),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: adjustDelta,
                    min: -0.1,
                    max: 0.1,
                    activeColor: accent,
                    inactiveColor: border,
                    onChanged: onAdjustChanged,
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}