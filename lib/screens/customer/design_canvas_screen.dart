import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/top_feedback_banner.dart';

/// The sketch board, lifted out of `TailoringSetupScreen` so more than one
/// screen can open it. It pops with the file path of the exported PNG, or
/// null if the customer backed out — callers only ever see an image.

enum _DrawTool { pencil, stitch, eraser, text }

/// Anything painted on the board. Kept in one ordered list so undo/redo and
/// paint order stay consistent across strokes and labels alike.
abstract class _CanvasItem {
  Map<String, dynamic> toJson();
}

/// A single stroke. Geometry is built incrementally as points arrive so that
/// painting is just a couple of `drawPath` calls instead of one `drawLine`
/// per segment. Jitter is baked in once (deterministic) rather than being
/// re-randomised on every repaint.
class _DrawStroke extends _CanvasItem {
  final Color color;
  final double width;
  final _DrawTool tool;
  final bool mirrored;

  /// Raw (unjittered) points, kept only so the draft can be serialised.
  final List<Offset> rawPoints = [];
  final List<Path> layers = [];
  final List<Offset> _cursor = [];
  final Random _rand;

  final Offset _firstPoint;
  Offset _lastPoint;
  int _pointCount = 1;

  Path? _dashCache;

  bool get isEraser => tool == _DrawTool.eraser;
  bool get isStitch => tool == _DrawTool.stitch;
  bool get isDot => _pointCount == 1;
  Offset get dotCenter => _firstPoint;

  _DrawStroke({
    required Offset start,
    required this.color,
    required this.width,
    required this.tool,
    required this.mirrored,
  }) : _rand = Random(start.dx.toInt() * 31 + start.dy.toInt() * 17),
       _firstPoint = start,
       _lastPoint = start {
    // Pencil gets two lightly offset passes for texture; stitch and eraser
    // stay crisp with a single pass.
    final int layerCount = tool == _DrawTool.pencil ? 2 : 1;
    rawPoints.add(start);
    for (int i = 0; i < layerCount; i++) {
      final p = _jitter(start);
      layers.add(Path()..moveTo(p.dx, p.dy));
      _cursor.add(p);
    }
  }

  Offset _jitter(Offset p) {
    if (tool != _DrawTool.pencil) return p;
    final range = width * 0.16;
    return Offset(
      p.dx + (_rand.nextDouble() - 0.5) * range,
      p.dy + (_rand.nextDouble() - 0.5) * range,
    );
  }

  /// Returns false when the point is too close to the previous one to matter.
  bool addPoint(Offset p, {bool force = false}) {
    if (!force && (p - _lastPoint).distanceSquared < 2.25) return false;
    _lastPoint = p;
    _pointCount++;
    rawPoints.add(p);
    for (int i = 0; i < layers.length; i++) {
      final jp = _jitter(p);
      final prev = _cursor[i];
      // Quadratic smoothing through segment midpoints.
      final mid = Offset((prev.dx + jp.dx) / 2, (prev.dy + jp.dy) / 2);
      layers[i].quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      _cursor[i] = jp;
    }
    _dashCache = null; // geometry changed — dashes must be rebuilt
    return true;
  }

  /// Dashed version of the path, used by the stitch tool. Cached, so only
  /// the stroke currently being drawn ever pays to rebuild it.
  Path get dashedPath => _dashCache ??= _buildDashed(layers.first, width);

  static Path _buildDashed(Path src, double w) {
    final double dash = (w * 2.4).clamp(6.0, 18.0);
    final double gap = (w * 1.5).clamp(4.0, 11.0);
    final out = Path();
    for (final metric in src.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final double end = min(d + dash, metric.length);
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d = end + gap;
      }
    }
    return out;
  }

  @override
  Map<String, dynamic> toJson() => {
    't': 's',
    'tool': tool.name,
    'c': color.toARGB32(),
    'w': width,
    'm': mirrored,
    'p': [
      for (final o in rawPoints) ...[o.dx, o.dy],
    ],
  };

  static _DrawStroke? fromJson(Map<String, dynamic> j, double sx, double sy) {
    final raw = (j['p'] as List?)?.cast<num>() ?? const [];
    if (raw.length < 2) return null;
    final tool = _DrawTool.values.firstWhere(
      (t) => t.name == j['tool'],
      orElse: () => _DrawTool.pencil,
    );
    final stroke = _DrawStroke(
      start: Offset(raw[0].toDouble() * sx, raw[1].toDouble() * sy),
      color: Color(j['c'] as int? ?? 0xFF1B1B1B),
      width: (j['w'] as num?)?.toDouble() ?? 4,
      tool: tool,
      mirrored: j['m'] as bool? ?? false,
    );
    for (int i = 2; i + 1 < raw.length; i += 2) {
      stroke.addPoint(
        Offset(raw[i].toDouble() * sx, raw[i + 1].toDouble() * sy),
        force: true,
      );
    }
    return stroke;
  }
}

/// A short note stamped onto the sketch — "puff sleeve", "3 inch cuff".
/// Never mirrored: a mirrored label would render backwards and unreadable.
class _TextLabel extends _CanvasItem {
  String text;
  Offset position; // centre of the label
  Color color;
  double fontSize;

  TextPainter? _painter;

  _TextLabel({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  }) {
    remeasure();
  }

  void remeasure() {
    _painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
  }

  Size get size => _painter?.size ?? Size.zero;

  Rect get bounds => Rect.fromCenter(
    center: position,
    width: size.width + 16,
    height: size.height + 12,
  );

  void paint(Canvas canvas) {
    final p = _painter;
    if (p == null) return;
    p.paint(
      canvas,
      Offset(position.dx - p.size.width / 2, position.dy - p.size.height / 2),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    't': 'l',
    's': text,
    'x': position.dx,
    'y': position.dy,
    'c': color.toARGB32(),
    'fs': fontSize,
  };

  static _TextLabel? fromJson(Map<String, dynamic> j, double sx, double sy) {
    final text = j['s'] as String?;
    if (text == null || text.isEmpty) return null;
    return _TextLabel(
      text: text,
      position: Offset(
        ((j['x'] as num?)?.toDouble() ?? 0) * sx,
        ((j['y'] as num?)?.toDouble() ?? 0) * sy,
      ),
      color: Color(j['c'] as int? ?? 0xFF1B1B1B),
      fontSize: (j['fs'] as num?)?.toDouble() ?? 18,
    );
  }
}

class DesignCanvasScreen extends StatefulWidget {
  /// Body diagram to trace over, or null for a blank white page.
  final String? templateAsset;

  /// Namespaces the autosaved draft. Two flows both open a blank board, and
  /// without this they share one draft — a sketch abandoned while ordering
  /// would reappear inside the virtual trial's board.
  final String draftScope;

  const DesignCanvasScreen({
    super.key,
    this.templateAsset,
    this.draftScope = 'order',
  });

  @override
  State<DesignCanvasScreen> createState() => DesignCanvasScreenState();
}

class DesignCanvasScreenState extends State<DesignCanvasScreen> {
  static const List<Color> _palette = [
    Color(0xFF1B1B1B),
    Color(0xFF6B7280),
    Color(0xFFE53935),
    Color(0xFFF4511E),
    Color(0xFFFBC02D),
    Color(0xFF2E7D32),
    Color(0xFF00897B),
    Color(0xFF1E88E5),
    Color(0xFF3949AB),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
  ];

  final GlobalKey _boundaryKey = GlobalKey();
  final List<_CanvasItem> _items = [];
  final List<_CanvasItem> _redoStack = [];

  /// Drives canvas repaints directly, so dragging never rebuilds the widget
  /// tree (toolbar, template image, Scaffold) — this is the main lag fix.
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  final TransformationController _zoom = TransformationController();

  _DrawTool _tool = _DrawTool.pencil;
  Color _color = _palette.first;
  double _brushSize = 4;
  double _fontSize = 18;
  double _templateOpacity = 1.0;
  bool _mirror = false;
  bool _isSaving = false;
  bool _isZoomed = false;

  // Active gesture state.
  int _activePointers = 0;
  _DrawStroke? _activeStroke;
  _TextLabel? _dragLabel;
  Offset _dragGrabOffset = Offset.zero;
  Offset? _dragStart;
  double _dragDistance = 0;

  // Draft autosave.
  Timer? _saveDebounce;
  Size? _canvasSize;
  bool _restoreChecked = false;

  bool get _isBlank => widget.templateAsset == null;

  String get _draftKey =>
      'sketch_draft_${widget.draftScope}_${widget.templateAsset ?? 'blank'}';

  double get _activeSizeValue =>
      _tool == _DrawTool.text ? _fontSize : _brushSize;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  // ── Draft persistence ────────────────────────────────────────────────

  void _scheduleDraftSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final size = _canvasSize;
    if (size == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_items.isEmpty) {
        await prefs.remove(_draftKey);
        return;
      }
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'w': size.width,
          'h': size.height,
          'items': [for (final i in _items) i.toJson()],
        }),
      );
    } catch (_) {
      // A failed draft save must never interrupt drawing.
    }
  }

  Future<void> _clearDraft() async {
    _saveDebounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _offerRestore() async {
    final size = _canvasSize;
    if (size == null || !mounted) return;
    Map<String, dynamic> data;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return;
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final list = (data['items'] as List?) ?? const [];
    if (list.isEmpty || !mounted) return;

    final bool? restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Restore your last sketch?"),
        content: const Text(
          "We saved the design you were working on. Continue where you left "
          "off, or start fresh.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Start fresh"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green.shade800,
            ),
            child: const Text("Restore"),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (restore != true) {
      _clearDraft();
      return;
    }

    // The draft may have been drawn at a different board size (rotation, a
    // different device) — scale the stored coordinates to fit this one.
    final double storedW = (data['w'] as num?)?.toDouble() ?? size.width;
    final double storedH = (data['h'] as num?)?.toDouble() ?? size.height;
    final double sx = storedW > 0 ? size.width / storedW : 1;
    final double sy = storedH > 0 ? size.height / storedH : 1;

    final restored = <_CanvasItem>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      final j = entry.cast<String, dynamic>();
      final item = j['t'] == 'l'
          ? _TextLabel.fromJson(j, sx, sy)
          : _DrawStroke.fromJson(j, sx, sy);
      if (item != null) restored.add(item);
    }
    if (restored.isEmpty) return;

    setState(() {
      _items
        ..clear()
        ..addAll(restored);
      _redoStack.clear();
    });
    _repaint.value++;
  }

  // ── Gestures ─────────────────────────────────────────────────────────

  void _abortActiveStroke() {
    final stroke = _activeStroke;
    if (stroke == null) return;
    _items.remove(stroke);
    _activeStroke = null;
    _repaint.value++;
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    // A second finger means the user is pinching to zoom, not drawing —
    // throw away the accidental stroke that the first finger started.
    if (_activePointers > 1) {
      _abortActiveStroke();
      _dragLabel = null;
      _dragStart = null; // so the pinch isn't mistaken for a note tap
      // Hand the gesture over to InteractiveViewer so two fingers can pan
      // as well as pinch. Rebuilds only on the 1->2 finger transition.
      if (_activePointers == 2) setState(() {});
      return;
    }

    final pos = event.localPosition;
    _dragStart = pos;
    _dragDistance = 0;

    if (_tool == _DrawTool.text) {
      // Grab an existing label if one was tapped (topmost first); otherwise
      // the tap becomes a new label on pointer-up.
      _dragLabel = null;
      for (final item in _items.reversed) {
        if (item is _TextLabel && item.bounds.contains(pos)) {
          _dragLabel = item;
          // Keep the grab point under the finger instead of snapping the
          // label's centre to it.
          _dragGrabOffset = item.position - pos;
          break;
        }
      }
      return;
    }

    final bool wasEmpty = _items.isEmpty;
    final stroke = _DrawStroke(
      start: pos,
      color: _color,
      width: _tool == _DrawTool.eraser ? _brushSize * 2.5 : _brushSize,
      tool: _tool,
      mirrored: _mirror,
    );
    _activeStroke = stroke;
    _items.add(stroke);
    _redoStack.clear();
    _repaint.value++;
    // Only rebuild when the toolbar's enabled state actually flips.
    if (wasEmpty) setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointers != 1) return;
    final pos = event.localPosition;
    _dragDistance += event.delta.distance;

    final label = _dragLabel;
    if (label != null) {
      label.position = pos + _dragGrabOffset;
      _repaint.value++;
      return;
    }

    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.addPoint(pos)) _repaint.value++;
  }

  void _onPointerUp(PointerEvent event) {
    final bool wasMultiTouch = _activePointers > 1;
    _activePointers = max(0, _activePointers - 1);
    if (wasMultiTouch && _activePointers <= 1) setState(() {});

    if (_tool == _DrawTool.text && _activePointers == 0) {
      final label = _dragLabel;
      final start = _dragStart;
      _dragLabel = null;
      if (label != null) {
        // A tap (rather than a drag) on a label opens it for editing.
        if (_dragDistance < 6) {
          _editLabel(label);
        } else {
          _scheduleDraftSave();
        }
        return;
      }
      if (start != null && _dragDistance < 6) _createLabel(start);
      return;
    }

    if (_activeStroke != null) {
      _activeStroke = null;
      _scheduleDraftSave();
    }
  }

  // ── Text labels ──────────────────────────────────────────────────────

  Future<void> _createLabel(Offset position) async {
    final text = await _promptForText();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      _items.add(
        _TextLabel(
          text: text,
          position: position,
          color: _color,
          fontSize: _fontSize,
        ),
      );
      _redoStack.clear();
    });
    _repaint.value++;
    _scheduleDraftSave();
  }

  Future<void> _editLabel(_TextLabel label) async {
    final text = await _promptForText(initial: label.text, allowDelete: true);
    if (!mounted) return;
    if (text == null) return; // cancelled
    setState(() {
      if (text.isEmpty) {
        _items.remove(label);
      } else {
        label.text = text;
        label.remeasure();
      }
      _redoStack.clear();
    });
    _repaint.value++;
    _scheduleDraftSave();
  }

  Future<String?> _promptForText({
    String initial = '',
    bool allowDelete = false,
  }) {
    String value = initial;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(allowDelete ? "Edit note" : "Add a note"),
          content: TextFormField(
            initialValue: initial,
            onChanged: (v) => value = v,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: "e.g. puff sleeve, 3 inch cuff",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onFieldSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            if (allowDelete)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                child: const Text("Delete"),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, value.trim()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade800,
              ),
              child: const Text("Done"),
            ),
        ],
      ),
    );
  }

  // ── History ──────────────────────────────────────────────────────────

  void _undo() {
    if (_items.isEmpty) return;
    setState(() => _redoStack.add(_items.removeLast()));
    _repaint.value++;
    _scheduleDraftSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() => _items.add(_redoStack.removeLast()));
    _repaint.value++;
    _scheduleDraftSave();
  }

  void _clearAll() {
    if (_items.isEmpty) return;
    setState(() {
      _redoStack
        ..clear()
        ..addAll(_items.reversed);
      _items.clear();
    });
    _repaint.value++;
    _scheduleDraftSave();
  }

  // ── Export ───────────────────────────────────────────────────────────

  Future<String?> _exportImage() async {
    try {
      // Make sure the latest strokes are actually painted before capturing.
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      if (byteData == null) return null;

      final Uint8List bytes = byteData.buffer.asUint8List();
      final file = File(
        '${Directory.systemTemp.path}/design_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _upload() async {
    if (_isSaving) return;
    if (_items.isEmpty) {
      AppFeedback.show(context, "Draw your design first.", isError: true);
      return;
    }
    setState(() => _isSaving = true);
    final path = await _exportImage();
    if (!mounted) return;
    if (path == null) {
      setState(() => _isSaving = false);
      AppFeedback.show(
        context,
        "Couldn't save the sketch. Try again.",
        isError: true,
      );
      return;
    }
    await _clearDraft();
    if (!mounted) return;
    Navigator.pop(context, path);
  }

  Future<void> _confirmDiscard() async {
    if (_items.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Discard sketch?"),
        content: const Text("Your drawing won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep drawing"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text("Discard"),
          ),
        ],
      ),
    );
    if (discard == true) {
      await _clearDraft();
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBF9),
        appBar: AppBar(
          title: Text(
            _isBlank ? "Blank Sketch" : "Sketch Design",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmDiscard,
            tooltip: "Cancel",
          ),
          actions: [
            IconButton(
              onPressed: _items.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo_rounded),
              tooltip: "Undo",
            ),
            IconButton(
              onPressed: _redoStack.isEmpty ? null : _redo,
              icon: const Icon(Icons.redo_rounded),
              tooltip: "Redo",
            ),
            IconButton(
              onPressed: _items.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: "Clear all",
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildBoard()),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_restoreChecked) {
            _restoreChecked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _offerRestore());
          }

          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _zoom,
                  // One finger draws; two fingers pinch to zoom and pan.
                  panEnabled: _activePointers > 1,
                  scaleEnabled: true,
                  minScale: 1,
                  maxScale: 4,
                  child: RepaintBoundary(
                    // Inside the viewer, so the export always captures the
                    // whole board at its natural size, never the zoomed view.
                    key: _boundaryKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (!_isBlank)
                            Opacity(
                              opacity: _templateOpacity,
                              child: Image.asset(
                                widget.templateAsset!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade50,
                                  child: Icon(
                                    Icons.checkroom_rounded,
                                    size: 60,
                                    color: Colors.green.shade100,
                                  ),
                                ),
                              ),
                            ),
                          Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: _onPointerDown,
                            onPointerMove: _onPointerMove,
                            onPointerUp: _onPointerUp,
                            onPointerCancel: _onPointerUp,
                            // Isolated so stroke repaints never touch the
                            // template image layer.
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _SketchPainter(_items, _repaint),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_mirror && !_isZoomed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _MirrorGuidePainter()),
                  ),
                ),
              if (_isZoomed)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _zoom.value = Matrix4.identity(),
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.zoom_out_map_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    final bool isText = _tool == _DrawTool.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _toolButton(Icons.edit_rounded, _DrawTool.pencil, "Pencil"),
                const SizedBox(width: 6),
                _toolButton(Icons.timeline_rounded, _DrawTool.stitch, "Stitch"),
                const SizedBox(width: 6),
                _toolButton(
                  Icons.auto_fix_normal_rounded,
                  _DrawTool.eraser,
                  "Eraser",
                ),
                const SizedBox(width: 6),
                _toolButton(Icons.title_rounded, _DrawTool.text, "Note"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 30,
                  child: Center(
                    child: isText
                        ? Text(
                            "A",
                            style: TextStyle(
                              fontSize: (_fontSize * 0.62).clamp(11, 22),
                              fontWeight: FontWeight.w700,
                              color: _color,
                            ),
                          )
                        : Container(
                            width: _brushSize.clamp(3, 24).toDouble(),
                            height: _brushSize.clamp(3, 24).toDouble(),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _tool == _DrawTool.eraser
                                  ? Colors.grey.shade400
                                  : _color,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 13,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                    ),
                    child: Slider(
                      value: _activeSizeValue,
                      min: isText ? 12 : 1,
                      max: isText ? 44 : 20,
                      activeColor: Colors.green.shade800,
                      inactiveColor: Colors.grey.shade200,
                      onChanged: (v) => setState(() {
                        if (isText) {
                          _fontSize = v;
                        } else {
                          _brushSize = v;
                        }
                      }),
                    ),
                  ),
                ),
                SizedBox(
                  width: 26,
                  child: Text(
                    _activeSizeValue.toStringAsFixed(0),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _palette.length,
                padding: EdgeInsets.zero,
                itemBuilder: (_, i) {
                  final c = _palette[i];
                  final bool isSelected =
                      _color == c && _tool != _DrawTool.eraser;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _color = c;
                      if (_tool == _DrawTool.eraser) _tool = _DrawTool.pencil;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 10),
                      width: 30,
                      height: 30,
                      padding: EdgeInsets.all(isSelected ? 3 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.green.shade800
                              : Colors.grey.shade200,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _mirrorToggle(),
                if (!_isBlank) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.contrast_rounded,
                    size: 17,
                    color: Colors.grey.shade500,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                      ),
                      child: Slider(
                        value: _templateOpacity,
                        min: 0,
                        max: 1,
                        activeColor: Colors.grey.shade600,
                        inactiveColor: Colors.grey.shade200,
                        onChanged: (v) =>
                            setState(() => _templateOpacity = v),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.shade200,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  _isSaving ? "Saving…" : "Save Design",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mirrorToggle() {
    return GestureDetector(
      onTap: () => setState(() => _mirror = !_mirror),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _mirror ? Colors.green.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flip_rounded,
              size: 16,
              color: _mirror ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 5),
            Text(
              "Mirror",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _mirror ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, _DrawTool tool, String label) {
    final bool isSelected = _tool == tool;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tool = tool),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.black54,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint centre line shown while mirror mode is on, so the customer can see
/// the axis their strokes are being reflected across.
class _MirrorGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const double dash = 7;
    const double gap = 6;
    final double x = size.width / 2;
    for (double y = 6; y < size.height - 6; y += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, min(y + dash, size.height - 6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MirrorGuidePainter oldDelegate) => false;
}

class _SketchPainter extends CustomPainter {
  final List<_CanvasItem> items;

  _SketchPainter(this.items, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    // A layer is needed so the eraser can punch through the strokes and
    // reveal the template underneath, instead of painting white over it.
    canvas.saveLayer(Offset.zero & size, Paint());

    for (final item in items) {
      if (item is _TextLabel) {
        // Labels are never mirrored — reflected text reads backwards.
        item.paint(canvas);
        continue;
      }
      if (item is! _DrawStroke) continue;

      _drawStroke(canvas, item);
      if (item.mirrored) {
        canvas.save();
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
        _drawStroke(canvas, item);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, _DrawStroke stroke) {
    final paint = Paint()
      ..strokeCap = stroke.isStitch ? StrokeCap.butt : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (stroke.isEraser) {
      paint
        ..color = Colors.black
        ..strokeWidth = stroke.width
        ..blendMode = BlendMode.clear;
      if (stroke.isDot) {
        canvas.drawCircle(
          stroke.dotCenter,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        canvas.drawPath(stroke.layers.first, paint);
      }
      return;
    }

    if (stroke.isDot) {
      canvas.drawCircle(
        stroke.dotCenter,
        stroke.width / 2,
        paint
          ..style = PaintingStyle.fill
          ..color = stroke.color,
      );
      return;
    }

    if (stroke.isStitch) {
      // Dashed run of "stitches" — marks a seam or hem rather than an
      // outline, so the tailor can tell construction lines from design lines.
      paint
        ..color = stroke.color
        ..strokeWidth = stroke.width;
      canvas.drawPath(stroke.dashedPath, paint);
      return;
    }

    // Two lightly offset passes give the pencil texture in 2 draw calls
    // instead of one drawLine per segment per layer.
    for (int layer = 0; layer < stroke.layers.length; layer++) {
      paint
        ..color = stroke.color.withValues(alpha: layer == 0 ? 0.72 : 0.38)
        ..strokeWidth = stroke.width * (layer == 0 ? 1.0 : 0.75);
      canvas.drawPath(stroke.layers[layer], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
