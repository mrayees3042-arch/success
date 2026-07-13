import 'dart:math';
import 'package:flutter/material.dart';

/// Animated stick figure widget that shows exercise movement patterns.
/// Each exercise has keyframe poses that smoothly interpolate in a loop.
class StickFigureWidget extends StatefulWidget {
  const StickFigureWidget({
    super.key,
    required this.exerciseName,
    required this.accentColor,
    this.size = 120.0,
    this.strokeWidth = 3.0,
  });

  final String exerciseName;
  final Color accentColor;
  final double size;
  final double strokeWidth;

  @override
  State<StickFigureWidget> createState() => _StickFigureWidgetState();
}

class _StickFigureWidgetState extends State<StickFigureWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _StickFigurePainter(
            exerciseName: widget.exerciseName,
            progress: _controller.value,
            accentColor: widget.accentColor,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

/// Represents joint positions for a stick figure pose
class _Pose {
  final Offset head;
  final Offset neck;
  final Offset leftShoulder;
  final Offset rightShoulder;
  final Offset leftElbow;
  final Offset rightElbow;
  final Offset leftHand;
  final Offset rightHand;
  final Offset hip;
  final Offset leftKnee;
  final Offset rightKnee;
  final Offset leftFoot;
  final Offset rightFoot;
  final double bodyYOffset; // vertical offset for jumps

  const _Pose({
    required this.head,
    required this.neck,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftElbow,
    required this.rightElbow,
    required this.leftHand,
    required this.rightHand,
    required this.hip,
    required this.leftKnee,
    required this.rightKnee,
    required this.leftFoot,
    required this.rightFoot,
    this.bodyYOffset = 0,
  });

  static _Pose lerp(_Pose a, _Pose b, double t) {
    return _Pose(
      head: Offset.lerp(a.head, b.head, t)!,
      neck: Offset.lerp(a.neck, b.neck, t)!,
      leftShoulder: Offset.lerp(a.leftShoulder, b.leftShoulder, t)!,
      rightShoulder: Offset.lerp(a.rightShoulder, b.rightShoulder, t)!,
      leftElbow: Offset.lerp(a.leftElbow, b.leftElbow, t)!,
      rightElbow: Offset.lerp(a.rightElbow, b.rightElbow, t)!,
      leftHand: Offset.lerp(a.leftHand, b.leftHand, t)!,
      rightHand: Offset.lerp(a.rightHand, b.rightHand, t)!,
      hip: Offset.lerp(a.hip, b.hip, t)!,
      leftKnee: Offset.lerp(a.leftKnee, b.leftKnee, t)!,
      rightKnee: Offset.lerp(a.rightKnee, b.rightKnee, t)!,
      leftFoot: Offset.lerp(a.leftFoot, b.leftFoot, t)!,
      rightFoot: Offset.lerp(a.rightFoot, b.rightFoot, t)!,
      bodyYOffset: a.bodyYOffset + (b.bodyYOffset - a.bodyYOffset) * t,
    );
  }
}

class _StickFigurePainter extends CustomPainter {
  final String exerciseName;
  final double progress;
  final Color accentColor;
  final double strokeWidth;

  _StickFigurePainter({
    required this.exerciseName,
    required this.progress,
    required this.accentColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final poses = _getPoses();
    if (poses.isEmpty) {
      _drawDefaultStanding(canvas, size);
      return;
    }

    // Smooth ping-pong interpolation between keyframes
    final t = _easeInOut(progress);
    final pose = _interpolatePoses(poses, t);

    _drawFigure(canvas, size, pose);
  }

  double _easeInOut(double t) {
    // Smooth sine-based ease for natural movement
    return (1 - cos(t * 2 * pi)) / 2;
  }

  _Pose _interpolatePoses(List<_Pose> poses, double t) {
    if (poses.length == 1) return poses[0];
    if (poses.length == 2) return _Pose.lerp(poses[0], poses[1], t);

    // Multi-pose interpolation: distribute evenly and pingpong
    final totalSegments = poses.length - 1;
    final scaled = t * totalSegments;
    final index = scaled.floor().clamp(0, totalSegments - 1);
    final localT = scaled - index;
    return _Pose.lerp(poses[index], poses[index + 1], localT);
  }

  void _drawFigure(Canvas canvas, Size size, _Pose pose) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 100; // Normalize to 100-unit coordinate system
    final yOff = pose.bodyYOffset * scale;

    Offset transform(Offset o) =>
        Offset(cx + o.dx * scale, cy + o.dy * scale + yOff);

    final bodyColor = const Color(0xFF66D99A);
    final jointColor = const Color(0xFF2ECC71);

    final paint = Paint()
      ..color = bodyColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = bodyColor.withValues(alpha: 0.15)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final jointPaint = Paint()
      ..color = jointColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // Draw connections with glow
    void drawLine(Offset a, Offset b) {
      final ta = transform(a);
      final tb = transform(b);
      canvas.drawLine(ta, tb, glowPaint);
      canvas.drawLine(ta, tb, paint);
    }

    void drawJoint(Offset o, double radius) {
      canvas.drawCircle(transform(o), radius * scale, jointPaint);
    }

    // Body lines
    drawLine(pose.head, pose.neck);
    drawLine(pose.neck, pose.leftShoulder);
    drawLine(pose.neck, pose.rightShoulder);
    drawLine(pose.leftShoulder, pose.leftElbow);
    drawLine(pose.rightShoulder, pose.rightElbow);
    drawLine(pose.leftElbow, pose.leftHand);
    drawLine(pose.rightElbow, pose.rightHand);
    drawLine(pose.neck, pose.hip);
    drawLine(pose.hip, pose.leftKnee);
    drawLine(pose.hip, pose.rightKnee);
    drawLine(pose.leftKnee, pose.leftFoot);
    drawLine(pose.rightKnee, pose.rightFoot);

    // Head circle
    final headCenter = transform(pose.head);
    canvas.drawCircle(headCenter, 5 * scale, glowPaint);
    canvas.drawCircle(headCenter, 5 * scale, paint);

    // Joint dots
    drawJoint(pose.neck, 1.5);
    drawJoint(pose.leftShoulder, 1.5);
    drawJoint(pose.rightShoulder, 1.5);
    drawJoint(pose.leftElbow, 1.5);
    drawJoint(pose.rightElbow, 1.5);
    drawJoint(pose.leftHand, 1.5);
    drawJoint(pose.rightHand, 1.5);
    drawJoint(pose.hip, 2.0);
    drawJoint(pose.leftKnee, 1.5);
    drawJoint(pose.rightKnee, 1.5);
    drawJoint(pose.leftFoot, 1.5);
    drawJoint(pose.rightFoot, 1.5);
  }

  void _drawDefaultStanding(Canvas canvas, Size size) {
    _drawFigure(canvas, size, _standing);
  }

  // ── POSE DATA ──
  // Coordinate system: x=0 center, y negative = up, y positive = down
  // Range roughly -40 to +40

  static const _celebratePoses = [
    _Pose(
      head: Offset(0, -32),
      neck: Offset(0, -22),
      leftShoulder: Offset(-10, -20),
      rightShoulder: Offset(10, -20),
      leftElbow: Offset(-14, -14),
      rightElbow: Offset(14, -14),
      leftHand: Offset(-16, -20),
      rightHand: Offset(16, -20),
      hip: Offset(0, 1),
      leftKnee: Offset(-8, 15),
      rightKnee: Offset(8, 15),
      leftFoot: Offset(-6, 28),
      rightFoot: Offset(6, 28),
      bodyYOffset: 2.0,
    ),
    _Pose(
      head: Offset(0, -45),
      neck: Offset(0, -35),
      leftShoulder: Offset(-10, -33),
      rightShoulder: Offset(10, -33),
      leftElbow: Offset(-16, -45),
      rightElbow: Offset(16, -45),
      leftHand: Offset(-20, -55),
      rightHand: Offset(20, -55),
      hip: Offset(0, -12),
      leftKnee: Offset(-6, 2),
      rightKnee: Offset(6, 2),
      leftFoot: Offset(-6, 16),
      rightFoot: Offset(6, 16),
      bodyYOffset: -10.0,
    ),
  ];

  static const _standing = _Pose(
    head: Offset(0, -35),
    neck: Offset(0, -25),
    leftShoulder: Offset(-10, -23),
    rightShoulder: Offset(10, -23),
    leftElbow: Offset(-12, -13),
    rightElbow: Offset(12, -13),
    leftHand: Offset(-10, -3),
    rightHand: Offset(10, -3),
    hip: Offset(0, -2),
    leftKnee: Offset(-6, 14),
    rightKnee: Offset(6, 14),
    leftFoot: Offset(-8, 30),
    rightFoot: Offset(8, 30),
  );

  List<_Pose> _getPoses() {
    final name = exerciseName.toLowerCase();

    if (name.contains('celebrate')) return _celebratePoses;
    if (name.contains('leg curl')) return _legCurlPoses;
    if (name.contains('leg extension')) return _legExtensionPoses;
    if (name.contains('pulldown') || name.contains('pull down')) return _latPulldownPoses;
    if (name.contains('crossover')) return _cableCrossoverPoses;
    if (name.contains('squat') && name.contains('jump')) return _jumpSquatPoses;
    if (name.contains('squat')) return _squatPoses;
    if (name.contains('lunge')) return _lungePoses;
    if (name.contains('glute') || name.contains('bridge')) return _gluteBridgePoses;
    if (name.contains('leg raise')) return _legRaisePoses;
    if (name.contains('calf')) return _calfRaisePoses;
    if (name.contains('push') && name.contains('up')) return _pushUpPoses;
    if (name.contains('pike')) return _pikePushUpPoses;
    if (name.contains('incline push')) return _pushUpPoses; // Similar motion
    if (name.contains('row') || name.contains('door')) return _rowPoses;
    if (name.contains('arm circle')) return _armCirclePoses;
    if (name.contains('plank')) return _plankPoses;
    if (name.contains('pull up') || name.contains('pull-up')) return _pullUpPoses;
    if (name.contains('shoulder press') || name.contains('press')) return _shoulderPressPoses;
    if (name.contains('bicep') || name.contains('curl')) return _bicepCurlPoses;
    if (name.contains('front raise')) return _frontRaisePoses;
    if (name.contains('reverse fly') || name.contains('fly')) return _reverseFlyPoses;
    if (name.contains('shrug')) return _shrugPoses;
    if (name.contains('bench')) return _benchPressPoses;
    if (name.contains('hinge')) return _hingePoses;
    if (name.contains('balance')) return _balancePoses;

    return [_standing]; // Default standing
  }

  // ── SQUAT ──
  static const _squatPoses = [
    _standing,
    _Pose(
      head: Offset(0, -22),
      neck: Offset(0, -14),
      leftShoulder: Offset(-10, -12),
      rightShoulder: Offset(10, -12),
      leftElbow: Offset(-16, -8),
      rightElbow: Offset(16, -8),
      leftHand: Offset(-18, -12),
      rightHand: Offset(18, -12),
      hip: Offset(0, 8),
      leftKnee: Offset(-12, 16),
      rightKnee: Offset(12, 16),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── JUMP SQUAT ──
  static const _jumpSquatPoses = [
    _standing,
    _Pose(
      head: Offset(0, -22),
      neck: Offset(0, -14),
      leftShoulder: Offset(-10, -12),
      rightShoulder: Offset(10, -12),
      leftElbow: Offset(-16, -8),
      rightElbow: Offset(16, -8),
      leftHand: Offset(-18, -12),
      rightHand: Offset(18, -12),
      hip: Offset(0, 8),
      leftKnee: Offset(-12, 16),
      rightKnee: Offset(12, 16),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
    _Pose(
      head: Offset(0, -45),
      neck: Offset(0, -37),
      leftShoulder: Offset(-10, -35),
      rightShoulder: Offset(10, -35),
      leftElbow: Offset(-14, -40),
      rightElbow: Offset(14, -40),
      leftHand: Offset(-12, -46),
      rightHand: Offset(12, -46),
      hip: Offset(0, -14),
      leftKnee: Offset(-6, 0),
      rightKnee: Offset(6, 0),
      leftFoot: Offset(-8, 14),
      rightFoot: Offset(8, 14),
      bodyYOffset: -8,
    ),
  ];

  // ── LUNGE ──
  static const _lungePoses = [
    _standing,
    _Pose(
      head: Offset(0, -28),
      neck: Offset(0, -20),
      leftShoulder: Offset(-10, -18),
      rightShoulder: Offset(10, -18),
      leftElbow: Offset(-12, -8),
      rightElbow: Offset(12, -8),
      leftHand: Offset(-10, 2),
      rightHand: Offset(10, 2),
      hip: Offset(0, 4),
      leftKnee: Offset(-14, 14),
      rightKnee: Offset(14, 14),
      leftFoot: Offset(-20, 30),
      rightFoot: Offset(16, 30),
    ),
  ];

  // ── GLUTE BRIDGE (side view) ──
  static const _gluteBridgePoses = [
    // Lying flat
    _Pose(
      head: Offset(-30, 22),
      neck: Offset(-22, 22),
      leftShoulder: Offset(-18, 22),
      rightShoulder: Offset(-18, 22),
      leftElbow: Offset(-14, 28),
      rightElbow: Offset(-14, 28),
      leftHand: Offset(-10, 28),
      rightHand: Offset(-10, 28),
      hip: Offset(0, 22),
      leftKnee: Offset(14, 14),
      rightKnee: Offset(14, 14),
      leftFoot: Offset(20, 28),
      rightFoot: Offset(20, 28),
    ),
    // Hips raised
    _Pose(
      head: Offset(-30, 22),
      neck: Offset(-22, 20),
      leftShoulder: Offset(-18, 20),
      rightShoulder: Offset(-18, 20),
      leftElbow: Offset(-14, 28),
      rightElbow: Offset(-14, 28),
      leftHand: Offset(-10, 28),
      rightHand: Offset(-10, 28),
      hip: Offset(0, 10),
      leftKnee: Offset(14, 14),
      rightKnee: Offset(14, 14),
      leftFoot: Offset(20, 28),
      rightFoot: Offset(20, 28),
    ),
  ];

  // ── LEG RAISE (side view) ──
  static const _legRaisePoses = [
    // Lying flat
    _Pose(
      head: Offset(-30, 22),
      neck: Offset(-22, 22),
      leftShoulder: Offset(-18, 22),
      rightShoulder: Offset(-18, 22),
      leftElbow: Offset(-14, 28),
      rightElbow: Offset(-14, 28),
      leftHand: Offset(-10, 28),
      rightHand: Offset(-10, 28),
      hip: Offset(0, 22),
      leftKnee: Offset(16, 22),
      rightKnee: Offset(16, 22),
      leftFoot: Offset(30, 22),
      rightFoot: Offset(30, 22),
    ),
    // Legs raised
    _Pose(
      head: Offset(-30, 22),
      neck: Offset(-22, 22),
      leftShoulder: Offset(-18, 22),
      rightShoulder: Offset(-18, 22),
      leftElbow: Offset(-14, 28),
      rightElbow: Offset(-14, 28),
      leftHand: Offset(-10, 28),
      rightHand: Offset(-10, 28),
      hip: Offset(0, 22),
      leftKnee: Offset(10, 4),
      rightKnee: Offset(10, 4),
      leftFoot: Offset(16, -12),
      rightFoot: Offset(16, -12),
    ),
  ];

  // ── CALF RAISE ──
  static const _calfRaisePoses = [
    _standing,
    _Pose(
      head: Offset(0, -40),
      neck: Offset(0, -30),
      leftShoulder: Offset(-10, -28),
      rightShoulder: Offset(10, -28),
      leftElbow: Offset(-12, -18),
      rightElbow: Offset(12, -18),
      leftHand: Offset(-10, -8),
      rightHand: Offset(10, -8),
      hip: Offset(0, -7),
      leftKnee: Offset(-6, 9),
      rightKnee: Offset(6, 9),
      leftFoot: Offset(-6, 24),
      rightFoot: Offset(6, 24),
      bodyYOffset: -5,
    ),
  ];

  // ── PUSH UP (side view) ──
  static const _pushUpPoses = [
    // Plank up
    _Pose(
      head: Offset(-28, 4),
      neck: Offset(-20, 6),
      leftShoulder: Offset(-16, 8),
      rightShoulder: Offset(-16, 8),
      leftElbow: Offset(-14, 18),
      rightElbow: Offset(-14, 18),
      leftHand: Offset(-14, 28),
      rightHand: Offset(-14, 28),
      hip: Offset(6, 10),
      leftKnee: Offset(18, 16),
      rightKnee: Offset(18, 16),
      leftFoot: Offset(28, 22),
      rightFoot: Offset(28, 22),
    ),
    // Plank down
    _Pose(
      head: Offset(-28, 16),
      neck: Offset(-20, 18),
      leftShoulder: Offset(-16, 20),
      rightShoulder: Offset(-16, 20),
      leftElbow: Offset(-22, 22),
      rightElbow: Offset(-22, 22),
      leftHand: Offset(-18, 28),
      rightHand: Offset(-18, 28),
      hip: Offset(6, 22),
      leftKnee: Offset(18, 24),
      rightKnee: Offset(18, 24),
      leftFoot: Offset(28, 26),
      rightFoot: Offset(28, 26),
    ),
  ];

  // ── PIKE PUSH UP ──
  static const _pikePushUpPoses = [
    // Pike up
    _Pose(
      head: Offset(-14, -10),
      neck: Offset(-10, -4),
      leftShoulder: Offset(-8, 0),
      rightShoulder: Offset(-8, 0),
      leftElbow: Offset(-10, 12),
      rightElbow: Offset(-10, 12),
      leftHand: Offset(-10, 26),
      rightHand: Offset(-10, 26),
      hip: Offset(0, -14),
      leftKnee: Offset(10, 6),
      rightKnee: Offset(10, 6),
      leftFoot: Offset(18, 26),
      rightFoot: Offset(18, 26),
    ),
    // Pike down
    _Pose(
      head: Offset(-12, 8),
      neck: Offset(-8, 6),
      leftShoulder: Offset(-6, 8),
      rightShoulder: Offset(-6, 8),
      leftElbow: Offset(-14, 16),
      rightElbow: Offset(-14, 16),
      leftHand: Offset(-12, 26),
      rightHand: Offset(-12, 26),
      hip: Offset(0, -8),
      leftKnee: Offset(10, 6),
      rightKnee: Offset(10, 6),
      leftFoot: Offset(18, 26),
      rightFoot: Offset(18, 26),
    ),
  ];

  // ── DOOR ROW ──
  static const _rowPoses = [
    // Extended
    _Pose(
      head: Offset(0, -30),
      neck: Offset(0, -22),
      leftShoulder: Offset(-10, -20),
      rightShoulder: Offset(10, -20),
      leftElbow: Offset(-18, -14),
      rightElbow: Offset(18, -14),
      leftHand: Offset(-24, -8),
      rightHand: Offset(24, -8),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
    // Pulled
    _Pose(
      head: Offset(0, -32),
      neck: Offset(0, -24),
      leftShoulder: Offset(-10, -22),
      rightShoulder: Offset(10, -22),
      leftElbow: Offset(-16, -14),
      rightElbow: Offset(16, -14),
      leftHand: Offset(-10, -16),
      rightHand: Offset(10, -16),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── ARM CIRCLES ──
  static const _armCirclePoses = [
    // Arms out
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-10, -23),
      rightShoulder: Offset(10, -23),
      leftElbow: Offset(-22, -23),
      rightElbow: Offset(22, -23),
      leftHand: Offset(-32, -23),
      rightHand: Offset(32, -23),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
    // Arms up
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-10, -23),
      rightShoulder: Offset(10, -23),
      leftElbow: Offset(-16, -36),
      rightElbow: Offset(16, -36),
      leftHand: Offset(-10, -44),
      rightHand: Offset(10, -44),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── PLANK ──
  static const _plankPoses = [
    _Pose(
      head: Offset(-28, 4),
      neck: Offset(-20, 6),
      leftShoulder: Offset(-16, 8),
      rightShoulder: Offset(-16, 8),
      leftElbow: Offset(-14, 18),
      rightElbow: Offset(-14, 18),
      leftHand: Offset(-14, 28),
      rightHand: Offset(-14, 28),
      hip: Offset(6, 10),
      leftKnee: Offset(18, 16),
      rightKnee: Offset(18, 16),
      leftFoot: Offset(28, 22),
      rightFoot: Offset(28, 22),
    ),
    // Slight sway for visual life
    _Pose(
      head: Offset(-28, 5),
      neck: Offset(-20, 7),
      leftShoulder: Offset(-16, 9),
      rightShoulder: Offset(-16, 9),
      leftElbow: Offset(-14, 19),
      rightElbow: Offset(-14, 19),
      leftHand: Offset(-14, 28),
      rightHand: Offset(-14, 28),
      hip: Offset(6, 12),
      leftKnee: Offset(18, 17),
      rightKnee: Offset(18, 17),
      leftFoot: Offset(28, 22),
      rightFoot: Offset(28, 22),
    ),
  ];

  // ── PULL UP (side view) ──
  static const _pullUpPoses = [
    // Hanging
    _Pose(
      head: Offset(0, -20),
      neck: Offset(0, -12),
      leftShoulder: Offset(-8, -10),
      rightShoulder: Offset(8, -10),
      leftElbow: Offset(-10, -22),
      rightElbow: Offset(10, -22),
      leftHand: Offset(-8, -34),
      rightHand: Offset(8, -34),
      hip: Offset(0, 6),
      leftKnee: Offset(-4, 20),
      rightKnee: Offset(4, 20),
      leftFoot: Offset(-4, 34),
      rightFoot: Offset(4, 34),
    ),
    // Pulled up
    _Pose(
      head: Offset(0, -34),
      neck: Offset(0, -28),
      leftShoulder: Offset(-8, -26),
      rightShoulder: Offset(8, -26),
      leftElbow: Offset(-14, -30),
      rightElbow: Offset(14, -30),
      leftHand: Offset(-8, -36),
      rightHand: Offset(8, -36),
      hip: Offset(0, -8),
      leftKnee: Offset(-4, 8),
      rightKnee: Offset(4, 8),
      leftFoot: Offset(-4, 22),
      rightFoot: Offset(4, 22),
    ),
  ];

  // ── SHOULDER PRESS (front view) ──
  static const _shoulderPressPoses = [
    // Arms at shoulder height
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-12, -23),
      rightShoulder: Offset(12, -23),
      leftElbow: Offset(-18, -18),
      rightElbow: Offset(18, -18),
      leftHand: Offset(-16, -26),
      rightHand: Offset(16, -26),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
    // Arms overhead
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-12, -23),
      rightShoulder: Offset(12, -23),
      leftElbow: Offset(-12, -36),
      rightElbow: Offset(12, -36),
      leftHand: Offset(-8, -46),
      rightHand: Offset(8, -46),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── BICEP CURL (front view) ──
  static const _bicepCurlPoses = [
    // Arms down
    _standing,
    // Arms curled
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-10, -23),
      rightShoulder: Offset(10, -23),
      leftElbow: Offset(-12, -13),
      rightElbow: Offset(12, -13),
      leftHand: Offset(-12, -22),
      rightHand: Offset(12, -22),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── FRONT RAISE (front view) ──
  static const _frontRaisePoses = [
    _standing,
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-10, -23),
      rightShoulder: Offset(10, -23),
      leftElbow: Offset(-12, -28),
      rightElbow: Offset(12, -28),
      leftHand: Offset(-14, -36),
      rightHand: Offset(14, -36),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── REVERSE FLY (front view, showing from back) ──
  static const _reverseFlyPoses = [
    // Arms forward
    _Pose(
      head: Offset(0, -30),
      neck: Offset(0, -22),
      leftShoulder: Offset(-10, -18),
      rightShoulder: Offset(10, -18),
      leftElbow: Offset(-8, -12),
      rightElbow: Offset(8, -12),
      leftHand: Offset(-4, -6),
      rightHand: Offset(4, -6),
      hip: Offset(0, 4),
      leftKnee: Offset(-6, 18),
      rightKnee: Offset(6, 18),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
    // Arms out
    _Pose(
      head: Offset(0, -30),
      neck: Offset(0, -22),
      leftShoulder: Offset(-10, -18),
      rightShoulder: Offset(10, -18),
      leftElbow: Offset(-22, -16),
      rightElbow: Offset(22, -16),
      leftHand: Offset(-32, -14),
      rightHand: Offset(32, -14),
      hip: Offset(0, 4),
      leftKnee: Offset(-6, 18),
      rightKnee: Offset(6, 18),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── SHRUG (front view) ──
  static const _shrugPoses = [
    _standing,
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-10, -28),
      rightShoulder: Offset(10, -28),
      leftElbow: Offset(-12, -18),
      rightElbow: Offset(12, -18),
      leftHand: Offset(-10, -8),
      rightHand: Offset(10, -8),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── BENCH PRESS (side view) ──
  static const _benchPressPoses = [
    // Arms extended
    _Pose(
      head: Offset(-30, 18),
      neck: Offset(-22, 18),
      leftShoulder: Offset(-18, 18),
      rightShoulder: Offset(-18, 18),
      leftElbow: Offset(-16, 4),
      rightElbow: Offset(-16, 4),
      leftHand: Offset(-16, -8),
      rightHand: Offset(-16, -8),
      hip: Offset(0, 20),
      leftKnee: Offset(14, 14),
      rightKnee: Offset(14, 14),
      leftFoot: Offset(20, 26),
      rightFoot: Offset(20, 26),
    ),
    // Arms lowered
    _Pose(
      head: Offset(-30, 18),
      neck: Offset(-22, 18),
      leftShoulder: Offset(-18, 18),
      rightShoulder: Offset(-18, 18),
      leftElbow: Offset(-24, 10),
      rightElbow: Offset(-24, 10),
      leftHand: Offset(-18, 16),
      rightHand: Offset(-18, 16),
      hip: Offset(0, 20),
      leftKnee: Offset(14, 14),
      rightKnee: Offset(14, 14),
      leftFoot: Offset(20, 26),
      rightFoot: Offset(20, 26),
    ),
  ];

  // ── HINGE ──
  static const _hingePoses = [
    _standing,
    _Pose(
      head: Offset(-20, -16),
      neck: Offset(-14, -10),
      leftShoulder: Offset(-10, -8),
      rightShoulder: Offset(-10, -8),
      leftElbow: Offset(-6, 0),
      rightElbow: Offset(-6, 0),
      leftHand: Offset(-2, 8),
      rightHand: Offset(-2, 8),
      hip: Offset(6, -2),
      leftKnee: Offset(0, 14),
      rightKnee: Offset(0, 14),
      leftFoot: Offset(-4, 30),
      rightFoot: Offset(4, 30),
    ),
  ];

  // ── BALANCE ──
  static const _balancePoses = [
    // Standing on one leg - left
    _Pose(
      head: Offset(-2, -35),
      neck: Offset(-2, -25),
      leftShoulder: Offset(-12, -23),
      rightShoulder: Offset(8, -23),
      leftElbow: Offset(-20, -18),
      rightElbow: Offset(16, -18),
      leftHand: Offset(-24, -14),
      rightHand: Offset(20, -14),
      hip: Offset(-2, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(10, 4),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(16, 8),
    ),
    // Slight sway right
    _Pose(
      head: Offset(2, -35),
      neck: Offset(2, -25),
      leftShoulder: Offset(-8, -23),
      rightShoulder: Offset(12, -23),
      leftElbow: Offset(-16, -18),
      rightElbow: Offset(20, -18),
      leftHand: Offset(-20, -14),
      rightHand: Offset(24, -14),
      hip: Offset(2, -2),
      leftKnee: Offset(-2, 14),
      rightKnee: Offset(14, 4),
      leftFoot: Offset(-4, 30),
      rightFoot: Offset(20, 8),
    ),
  ];

  // ── LEG CURL (side view, lying face down) ──
  static const _legCurlPoses = [
    _Pose(
      head: Offset(-30, 24),
      neck: Offset(-22, 24),
      leftShoulder: Offset(-18, 24),
      rightShoulder: Offset(-18, 24),
      leftElbow: Offset(-14, 28),
      rightElbow: Offset(-14, 28),
      leftHand: Offset(-10, 28),
      rightHand: Offset(-10, 28),
      hip: Offset(2, 24),
      leftKnee: Offset(16, 24),
      rightKnee: Offset(16, 24),
      leftFoot: Offset(30, 24),
      rightFoot: Offset(30, 24),
    ),
    _Pose(
      head: Offset(-30, 24),
      neck: Offset(-22, 24),
      leftShoulder: Offset(-18, 24),
      rightShoulder: Offset(-18, 24),
      leftElbow: Offset(-14, 28),
      rightElbow: Offset(-14, 28),
      leftHand: Offset(-10, 28),
      rightHand: Offset(-10, 28),
      hip: Offset(2, 24),
      leftKnee: Offset(14, 24),
      rightKnee: Offset(14, 24),
      leftFoot: Offset(10, 8),
      rightFoot: Offset(10, 8),
    ),
  ];

  // ── LEG EXTENSION (side view, sitting) ──
  static const _legExtensionPoses = [
    _Pose(
      head: Offset(0, -25),
      neck: Offset(0, -17),
      leftShoulder: Offset(0, -13),
      rightShoulder: Offset(0, -13),
      leftElbow: Offset(-6, -4),
      rightElbow: Offset(6, -4),
      leftHand: Offset(-6, 12),
      rightHand: Offset(6, 12),
      hip: Offset(0, 10),
      leftKnee: Offset(14, 10),
      rightKnee: Offset(14, 10),
      leftFoot: Offset(14, 26),
      rightFoot: Offset(14, 26),
    ),
    _Pose(
      head: Offset(0, -25),
      neck: Offset(0, -17),
      leftShoulder: Offset(0, -13),
      rightShoulder: Offset(0, -13),
      leftElbow: Offset(-6, -4),
      rightElbow: Offset(6, -4),
      leftHand: Offset(-6, 12),
      rightHand: Offset(6, 12),
      hip: Offset(0, 10),
      leftKnee: Offset(14, 10),
      rightKnee: Offset(14, 10),
      leftFoot: Offset(28, 10),
      rightFoot: Offset(28, 10),
    ),
  ];

  // ── LAT PULLDOWN (front view, sitting) ──
  static const _latPulldownPoses = [
    _Pose(
      head: Offset(0, -15),
      neck: Offset(0, -7),
      leftShoulder: Offset(-8, -4),
      rightShoulder: Offset(8, -4),
      leftElbow: Offset(-14, -18),
      rightElbow: Offset(14, -18),
      leftHand: Offset(-12, -30),
      rightHand: Offset(12, -30),
      hip: Offset(0, 16),
      leftKnee: Offset(-6, 22),
      rightKnee: Offset(6, 22),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
    _Pose(
      head: Offset(0, -15),
      neck: Offset(0, -7),
      leftShoulder: Offset(-8, -4),
      rightShoulder: Offset(8, -4),
      leftElbow: Offset(-14, 2),
      rightElbow: Offset(14, 2),
      leftHand: Offset(-10, -6),
      rightHand: Offset(10, -6),
      hip: Offset(0, 16),
      leftKnee: Offset(-6, 22),
      rightKnee: Offset(6, 22),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  // ── CABLE CROSSOVER (front view, standing) ──
  static const _cableCrossoverPoses = [
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-10, -23),
      rightShoulder: Offset(10, -23),
      leftElbow: Offset(-22, -23),
      rightElbow: Offset(22, -23),
      leftHand: Offset(-32, -23),
      rightHand: Offset(32, -23),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
    _Pose(
      head: Offset(0, -35),
      neck: Offset(0, -25),
      leftShoulder: Offset(-10, -23),
      rightShoulder: Offset(10, -23),
      leftElbow: Offset(-10, -13),
      rightElbow: Offset(10, -13),
      leftHand: Offset(0, -10),
      rightHand: Offset(0, -10),
      hip: Offset(0, -2),
      leftKnee: Offset(-6, 14),
      rightKnee: Offset(6, 14),
      leftFoot: Offset(-8, 30),
      rightFoot: Offset(8, 30),
    ),
  ];

  @override
  bool shouldRepaint(covariant _StickFigurePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.exerciseName != exerciseName ||
      oldDelegate.accentColor != accentColor;
}
