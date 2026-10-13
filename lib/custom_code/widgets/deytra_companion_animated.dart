// Automatic FlutterFlow imports
import '/flutter_flow/ff_builtin_enums.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:math' as math;

/// The original Deytra PNG with visually reviewed code-native eye overlays.
///
/// Programmed opening, blinking and gaze; no camera, pointer tracking, or
/// API. The original raster remains untouched. No arm articulation or extra
/// packages.
///
/// [imagePath] is a registered asset key or a verified HTTPS image URL. Use
/// [active] for a retained Home tab: false offscreen, true on entry.
/// Rebuilding does not replay the greeting. Mounting or false -> true does.
/// TickerMode/app-background pauses resume their current pose without replay.
class DeytraCompanionAnimated extends StatefulWidget {
  const DeytraCompanionAnimated({
    super.key,
    this.width,
    this.height,
    required this.imagePath,
    this.active = true,
  })  : assert(width == null || (width > 0 && width < double.infinity)),
        assert(height == null || (height > 0 && height < double.infinity));

  final double? width;
  final double? height;
  final String imagePath;
  final bool active;

  @override
  State<DeytraCompanionAnimated> createState() =>
      _DeytraCompanionAnimatedState();
}

class _DeytraCompanionAnimatedState extends State<DeytraCompanionAnimated>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _greeting;
  late final AnimationController _idle;
  late final Listenable _motion;
  bool _greetingDone = false;
  bool _reducedMotion = false;
  bool _tickersEnabled = false;
  bool _inForeground = true;
  bool _imageReady = false;
  bool _readyScheduled = false;
  int _imageEpoch = 0;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _inForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _greeting = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener(_onGreetingStatus);
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10400),
    );
    _motion = Listenable.merge([_greeting, _idle]);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
            _platformRequestsReducedMotion();
    _tickersEnabled = TickerMode.of(context);
    _syncPlayback();
  }

  bool _platformRequestsReducedMotion() {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    var reduced = features.disableAnimations || features.accessibleNavigation;
    try {
      reduced = reduced || (features as dynamic).reduceMotion == true;
    } on NoSuchMethodError {
      // Retain the flags available in FlutterFlow's pinned engine version.
    }
    return reduced;
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (!mounted) return;
    setState(() {
      _reducedMotion =
          (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
              _platformRequestsReducedMotion();
    });
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant DeytraCompanionAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    final imageChanged = oldWidget.imagePath != widget.imagePath;
    if (imageChanged) {
      _imageEpoch++;
      _imageReady = false;
      _readyScheduled = false;
    }
    if (imageChanged || (!oldWidget.active && widget.active)) {
      _greeting.stop(canceled: false);
      _idle.stop(canceled: false);
      _greetingDone = false;
      _greeting.value = 0;
      _idle.value = 0;
    }
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  void _onGreetingStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _greetingDone = true;
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (_reducedMotion) {
      // Remain still, and avoid a delayed greeting if this setting changes.
      _greetingDone = true;
    }
    final canAnimate = widget.active &&
        _tickersEnabled &&
        _inForeground &&
        !_reducedMotion &&
        _imageReady;
    if (!canAnimate) {
      // Explicit stop preserves progress; a muted ticker alone can jump ahead.
      _greeting.stop(canceled: false);
      _idle.stop(canceled: false);
      return;
    }
    if (_greetingDone) {
      if (!_idle.isAnimating) _idle.repeat();
    } else if (!_greeting.isAnimating) {
      _greeting.forward();
    }
  }

  void _markImageReady(int epoch) {
    if (_imageReady || _readyScheduled || epoch != _imageEpoch) return;
    _readyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _imageEpoch) return;
      _readyScheduled = false;
      _imageReady = true;
      _syncPlayback();
    });
  }

  Widget _buildImage() {
    final path = widget.imagePath.trim();
    final epoch = _imageEpoch;
    Widget onFrame(BuildContext context, Widget child, int? frame, bool sync) {
      if (frame != null) _markImageReady(epoch);
      return child;
    }

    Widget onError(BuildContext context, Object error, StackTrace? stack) =>
        const Center(
          child: Icon(Icons.assistant_outlined, color: Color(0xFFFF8A00)),
        );

    Widget onAssetError(BuildContext context, Object error, StackTrace? stack) {
      if (path != 'assets/images/assistant.png') {
        return onError(context, error, stack);
      }
      // If this exact project asset fails, try only the same verified original.
      // Other asset failures keep the local icon; no inferred URLs or retries.
      return Image.network(
        'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/deytra-aefqye/assets/a334fr0r27ug/assistant.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        frameBuilder: onFrame,
        errorBuilder: onError,
      );
    }

    if (path.isEmpty) return onError(context, 'Empty image path', null);
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'https' || uri.host.isEmpty) {
        return onError(context, 'Expected an HTTPS image URL', null);
      }
      return Image.network(path,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          frameBuilder: onFrame,
          errorBuilder: onError);
    }
    return Image.asset(path,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        frameBuilder: onFrame,
        errorBuilder: onAssetError);
  }

  @override
  Widget build(BuildContext context) {
    final width =
        widget.width ?? (widget.height == null ? 64.0 : widget.height! / 1.2);
    final height = widget.height ?? width * 1.2;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRect(
              child: LayoutBuilder(builder: (context, constraints) {
                // The PNG already has transparent margins around the robot.
                final scale = math
                    .min(constraints.maxWidth / 64.0,
                        constraints.maxHeight / 76.8)
                    .clamp(0.0, 1.0)
                    .toDouble();
                return AnimatedBuilder(
                  animation: _motion,
                  child: _buildImage(),
                  builder: (context, child) {
                    double y = 0;
                    double tilt = 0;
                    if (!_reducedMotion && widget.active && _imageReady) {
                      if (_greetingDone) {
                        final wave = math.sin(2 * math.pi * _idle.value);
                        y = -1.5 * scale * wave * wave;
                      } else {
                        final p = _greeting.value;
                        final envelope = math.sin(math.pi * p);
                        y = -3.0 * scale * envelope * envelope;
                        tilt = 0.028 * math.sin(2 * math.pi * p) * envelope;
                      }
                    }
                    return Transform.translate(
                      key: const ValueKey('deytraRobotTranslation'),
                      offset: Offset(0, y),
                      child: Transform.rotate(
                        key: const ValueKey('deytraRobotTilt'),
                        angle: tilt,
                        alignment: const Alignment(0, 0.65),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            child!,
                            if (_imageReady && !_reducedMotion)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _DeytraEyePainter(
                                    _DeytraEyePose.fromMotion(
                                      greeting: _greeting.value,
                                      idle: _idle.value,
                                      greetingDone: _greetingDone,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _greeting.removeStatusListener(_onGreetingStatus);
    _greeting.dispose();
    _idle.dispose();
    super.dispose();
  }
}

/// A deterministic pose. Gaze is a scheduled expression, never user tracking.
@immutable
class _DeytraEyePose {
  const _DeytraEyePose({
    required this.open,
    required this.blink,
    required this.gaze,
    required this.opacity,
  });
  final double open;
  final double blink;
  final double gaze;
  final double opacity;

  static double _smooth(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return t * t * (3.0 - 2.0 * t);
  }

  static double _pulse(double t, double start, double peak, double end) =>
      t < peak
          ? _smooth((t - start) / (peak - start))
          : 1 - _smooth((t - peak) / (end - peak));

  static double _look(
          double t, double start, double arrive, double leave, double end) =>
      t < arrive
          ? _smooth((t - start) / (arrive - start))
          : 1 - _smooth((t - leave) / (end - leave));

  factory _DeytraEyePose.fromMotion({
    required double greeting,
    required double idle,
    required bool greetingDone,
  }) {
    if (!greetingDone) {
      return _DeytraEyePose(
        opacity: _smooth(greeting / 0.12),
        open: _smooth((greeting - 0.15) / 0.65),
        blink: 0,
        gaze: 0,
      );
    }
    return _DeytraEyePose(
      opacity: 1,
      open: 1,
      blink: _pulse(idle, 0.20, 0.212, 0.224),
      gaze: _look(idle, 0.36, 0.40, 0.44, 0.48) -
          _look(idle, 0.70, 0.74, 0.78, 0.82),
    );
  }
}

class _DeytraEyePainter extends CustomPainter {
  const _DeytraEyePainter(this.pose);
  final _DeytraEyePose pose;

  // Coordinates belong to the verified 1145 x 1374 original PNG only.
  static const _smile = <Offset>[
    Offset(-50, 17),
    Offset(-37, -48),
    Offset(37, -48),
    Offset(50, 17),
    Offset(53, 28),
    Offset(37, 29),
    Offset(34, 17),
    Offset(19, -18),
    Offset(-19, -18),
    Offset(-34, 17),
    Offset(-38, 29),
    Offset(-53, 28),
    Offset(-50, 17),
  ];
  static const _awake = <Offset>[
    Offset(-28, 0),
    Offset(-28, -55),
    Offset(28, -55),
    Offset(28, 0),
    Offset(28, 10),
    Offset(27, 15),
    Offset(26, 20),
    Offset(18, 50),
    Offset(-18, 50),
    Offset(-26, 20),
    Offset(-28, 15),
    Offset(-28, 10),
    Offset(-28, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || pose.opacity <= 0) return;
    final scale = math.min(size.width / 1145, size.height / 1374);
    canvas.save();
    canvas.translate(
        (size.width - 1145 * scale) / 2, (size.height - 1374 * scale) / 2);
    canvas.scale(scale);
    canvas.saveLayer(const Rect.fromLTRB(400, 290, 845, 480),
        Paint()..color = Color.fromRGBO(255, 255, 255, pose.opacity));

    // Feather only the two baked-in eyes; retain the surrounding screen,
    // its specular edge, the shell, and every other original character pixel.
    _patch(
        canvas,
        const Rect.fromLTWH(409, 305, 182, 140),
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151313), Color(0xFF0E0C0C)],
        ));
    _patch(
        canvas,
        const Rect.fromLTWH(651, 325, 180, 144),
        const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF121010), Color(0xFF211C19), Color(0xFF42332C)],
          stops: [0, 0.48, 1],
        ));
    _eye(canvas, Offset(500 + pose.gaze * 10, 376), 1);
    _eye(canvas, Offset(741 + pose.gaze * 10, 398), 0.93);
    canvas.restore();
    canvas.restore();
  }

  void _patch(Canvas canvas, Rect rect, Gradient background) {
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..shader = background.createShader(rect));
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(rect.width / 2, rect.height / 2);
    const normalized = Rect.fromLTRB(-1, -1, 1, 1);
    // Draw the whole rectangle: transparent corners must erase the layer too.
    canvas.drawRect(
        normalized,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const RadialGradient(
            radius: 0.5,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.8, 1],
          ).createShader(normalized));
    canvas.restore();
    canvas.restore();
  }

  void _eye(Canvas canvas, Offset center, double ratio) {
    Offset point(int i) {
      final p = Offset.lerp(_smile[i], _awake[i], pose.open)!;
      return Offset(center.dx + p.dx * ratio,
          center.dy + p.dy * ratio * (1 - pose.blink * 0.9));
    }

    final first = point(0);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < 13; i += 3) {
      final a = point(i), b = point(i + 1), c = point(i + 2);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xBFFF7900)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Scale the shader in eye-local coordinates to match the SVG proof.
    final bounds = path.getBounds();
    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    canvas.scale(bounds.width, bounds.height);
    final normalizedPath = path.transform(
      (Matrix4.identity()
            ..scale(1 / bounds.width, 1 / bounds.height)
            ..translate(-bounds.left, -bounds.top))
          .storage,
    );
    canvas.drawPath(
        normalizedPath,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.06, -0.2),
            radius: 0.65,
            colors: [
              Color(0xFFFFF5BD),
              Color(0xFFFFCF78),
              Color(0xFFFF990B),
              Color(0xFFFF7800)
            ],
            stops: [0, 0.5, 0.85, 1],
          ).createShader(const Rect.fromLTWH(0, 0, 1, 1)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DeytraEyePainter oldDelegate) =>
      oldDelegate.pose.open != pose.open ||
      oldDelegate.pose.blink != pose.blink ||
      oldDelegate.pose.gaze != pose.gaze ||
      oldDelegate.pose.opacity != pose.opacity;
}
