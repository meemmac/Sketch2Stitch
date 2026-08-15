import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Glassmorphic feedback banner pinned to the top of the screen.
/// Used in place of a bottom SnackBar so success/error messages read
/// consistently everywhere in the app (drawer profile edit, measurements,
/// registration, etc).
///
/// Usage pattern in a screen's State class:
///
/// ```dart
/// String? _feedbackMessage;
/// bool _feedbackIsError = false;
/// Timer? _feedbackTimer;
///
/// void _showFeedback(String message, {bool isError = false}) {
///   _feedbackTimer?.cancel();
///   setState(() {
///     _feedbackMessage = message;
///     _feedbackIsError = isError;
///   });
///   _feedbackTimer = Timer(const Duration(seconds: 4), () {
///     if (mounted) setState(() => _feedbackMessage = null);
///   });
/// }
///
/// @override
/// void dispose() {
///   _feedbackTimer?.cancel();
///   super.dispose();
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return Stack(
///     children: [
///       _buildScaffold(), // your actual screen content
///       if (_feedbackMessage != null)
///         TopFeedbackBanner(
///           message: _feedbackMessage!,
///           isError: _feedbackIsError,
///           onClose: () => setState(() => _feedbackMessage = null),
///         ),
///     ],
///   );
/// }
/// ```
class TopFeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onClose;

  const TopFeedbackBanner({
    super.key,
    required this.message,
    required this.isError,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          bottom: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isError
                      ? const Color(0xFFFFEBEE).withValues(alpha: 0.92)
                      : const Color(0xFFC8E6C9).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isError
                        ? const Color(0xFFFFCDD2)
                        : const Color(0xFF9CCC9F),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isError
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF2E7D32))
                              .withValues(alpha: 0.10),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isError
                            ? const Color(0xFFE53935)
                            : const Color(0xFF4CAF50),
                        border: Border.all(
                          color: isError
                              ? const Color(0xFFEF9A9A)
                              : const Color(0xFFA5D6A7),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isError ? Icons.close_rounded : Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.35,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.black.withValues(alpha: 0.45),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App-wide entry point for transient messages that have no buttons.
/// Shows the exact same banner as [TopFeedbackBanner] (same look, same font)
/// in the root overlay, so any screen can call it without Stack plumbing and
/// the message never slides up from the bottom like a SnackBar.
///
/// ```dart
/// AppFeedback.show(context, 'Logged out successfully!');
/// AppFeedback.show(context, 'Something went wrong', isError: true);
/// ```
class AppFeedback {
  AppFeedback._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();

    final entry = OverlayEntry(
      builder: (_) => _AnimatedBanner(
        message: message,
        isError: isError,
        onClose: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// Fades/slides the banner down from the top edge (never up from the bottom).
class _AnimatedBanner extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onClose;

  const _AnimatedBanner({
    required this.message,
    required this.isError,
    required this.onClose,
  });

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.35),
          end: Offset.zero,
        ).animate(curve),
        child: Stack(
          children: [
            TopFeedbackBanner(
              message: widget.message,
              isError: widget.isError,
              onClose: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mixin that gives any State the standard _showFeedback/_feedbackTimer
/// plumbing so screens don't have to hand-copy the boilerplate. Optional —
/// use it, or just copy the pattern shown in the doc comment above.
mixin FeedbackBannerMixin<T extends StatefulWidget> on State<T> {
  String? feedbackMessage;
  bool feedbackIsError = false;
  Timer? _feedbackTimer;

  void showFeedback(String message, {bool isError = false}) {
    _feedbackTimer?.cancel();
    setState(() {
      feedbackMessage = message;
      feedbackIsError = isError;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => feedbackMessage = null);
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  /// Wrap your screen's normal build output with this to overlay the banner.
  Widget buildWithFeedbackBanner(Widget child) {
    return Stack(
      children: [
        child,
        if (feedbackMessage != null)
          TopFeedbackBanner(
            message: feedbackMessage!,
            isError: feedbackIsError,
            onClose: () => setState(() => feedbackMessage = null),
          ),
      ],
    );
  }
}