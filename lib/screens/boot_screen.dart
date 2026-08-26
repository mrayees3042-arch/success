import '../core/app_fonts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:success/main.dart';
import 'package:success/providers/theme_provider.dart';
import 'package:success/screens/onboarding_screen.dart';
import 'package:success/services/app_open_service.dart';
import 'package:success/services/audio_service.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _shineController;
  late AnimationController _ringController;
  late AnimationController _orbitController;
  late AnimationController _sequenceController;

  // Animations driven by sequence controller
  late Animation<double> _starScale;
  late Animation<double> _starRotate;
  late Animation<double> _arabicFadeUp;
  late Animation<double> _arabicSlideUp;
  late Animation<double> _englishFadeUp;
  late Animation<double> _englishSlideUp;
  late Animation<double> _builtForFadeUp;
  late Animation<double> _builtForSlideUp;
  late Animation<double> _taglineFadeUp;
  late Animation<double> _taglineSlideUp;
  late Animation<double> _progressBarFade;
  late Animation<double> _progressBarFill;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();

    // Record verified user app launch event
    AppOpenService.recordAppOpen();

    // 1. App Launch sound (Triggered instantly since native player is pre-warmed)
    AudioService.playLaunch();

    // 2. Infinite rotation for the star (15s per revolution to match CSS)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // 3. Infinite shine sweep (2.5s ease-in-out alternate to match CSS)
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // 4. Infinite ring breathe (3s ease-in-out to match CSS)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 5. Infinite orbit rotation (8s linear spin to match CSS)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 6. Main 8-second sequence controller
    _sequenceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // Star Fly-in: scale from 0.4 + rotate -120 deg (to match CSS)
    const starCurve = Cubic(0.23, 1.0, 0.32, 1.0);
    _starScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.2 / 8.0, 1.0 / 8.0, curve: starCurve),
      ),
    );
    _starRotate = Tween<double>(begin: -120 * math.pi / 180, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.2 / 8.0, 1.0 / 8.0, curve: starCurve),
      ),
    );

    // Fade-up timings (to match CSS delays)
    _arabicFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.4 / 8.0, curve: Curves.easeOut),
      ),
    );
    _arabicSlideUp = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.4 / 8.0, curve: Curves.easeOut),
      ),
    );

    _englishFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.4 / 8.0, curve: Curves.easeOut),
      ),
    );
    _englishSlideUp = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.4 / 8.0, curve: Curves.easeOut),
      ),
    );

    // "Built for" + "RAYEES" fade-up: 2.0s
    _builtForFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.0 / 8.0, curve: Curves.easeOut),
      ),
    );
    _builtForSlideUp = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.0 / 8.0, curve: Curves.easeOut),
      ),
    );

    // Tagline fade-up: 2.6s
    _taglineFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.6 / 8.0, curve: Curves.easeOut),
      ),
    );
    _taglineSlideUp = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.6 / 8.0, curve: Curves.easeOut),
      ),
    );

    // Progress bar fade-in: 2.8s
    _progressBarFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.8 / 8.0, curve: Curves.easeIn),
      ),
    );

    // Progress bar fill: 0 -> 100% over 5s starting at 3.0s (ends at 8.0s)
    _progressBarFill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(3.0 / 8.0, 8.0 / 8.0, curve: Curves.easeInOut),
      ),
    );

    // Start sequence
    _sequenceController.forward().then((_) async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('user_name');
        final firstBootCompleted = prefs.getBool('first_boot_completed') ?? (name != null && name.trim().isNotEmpty);
        final isConfigured = firstBootCompleted;

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) =>
                isConfigured ? const MainScreen() : const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (name != null && mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _shineController.dispose();
    _ringController.dispose();
    _orbitController.dispose();
    _sequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDark;
    
    // Background color: #06060F dark or #F5F0E8 in light mode
    final bgColor = isDark ? const Color(0xFF06060F) : const Color(0xFFF5F0E8);
    final goldColor = isDark ? const Color(0xFFE8B84B) : const Color(0xFFA0720A);
    final text3Color = isDark ? const Color(0x33FFFFFF) : const Color(0x26000000); // Built for label opacity
    final text4Color = isDark ? const Color(0x80FFFFFF) : const Color(0x66000000); // Rayees name opacity
    final tagColor = isDark ? const Color(0x38FFFFFF) : const Color(0x38000000);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const SizedBox(height: 12),

                    // Arabic Text: "مُتَّقِين"
                    AnimatedBuilder(
                      animation: _sequenceController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _arabicFadeUp.value,
                          child: Transform.translate(
                            offset: Offset(0, _arabicSlideUp.value),
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  goldColor,
                                  const Color(0xFFF5D78E),
                                  goldColor,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ).createShader(bounds),
                              child: Text(
                                "مُتَّقِين",
                                style: AppFonts.arabic(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 6),

                    // English Text: "Muttaqin"
                    AnimatedBuilder(
                      animation: _sequenceController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _englishFadeUp.value,
                          child: Transform.translate(
                            offset: Offset(0, _englishSlideUp.value),
                            child: Text(
                              "MUTTAQIN",
                              style: AppFonts.display(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: goldColor.withValues(alpha: 0.65),
                                letterSpacing: 10,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Built For & RAYEES
                    AnimatedBuilder(
                      animation: _sequenceController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _builtForFadeUp.value,
                          child: Transform.translate(
                            offset: Offset(0, _builtForSlideUp.value),
                            child: Column(
                              children: [
                                Text(
                                  "BUILT FOR",
                                  style: AppFonts.text(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: text3Color,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _userName.trim().isNotEmpty
                                      ? _userName.trim().toUpperCase()
                                      : "YOU",
                                  style: AppFonts.display(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: text4Color,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 44),

                    // Premium Glowing Progress Bar
                    AnimatedBuilder(
                      animation: _sequenceController,
                      builder: (context, child) {
                        final fillVal = _progressBarFill.value;
                        return Opacity(
                          opacity: _progressBarFade.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 140,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? Colors.white.withValues(alpha: 0.08) 
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.transparent,
                                    width: 0.5,
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Stack(
                                  children: [
                                    FractionallySizedBox(
                                      widthFactor: fillVal.clamp(0.01, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              goldColor,
                                              const Color(0xFF00C896),
                                              const Color(0xFF38BDF8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00C896).withValues(alpha: 0.6),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(fillVal * 100).round()}%',
                                style: AppFonts.text(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFF00C896).withValues(alpha: 0.8)
                                      : const Color(0xFF0A7A5A),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            // Tagline at bottom
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _sequenceController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _taglineFadeUp.value,
                    child: Transform.translate(
                      offset: Offset(0, _taglineSlideUp.value),
                      child: Text(
                        "“Indeed, with hardship comes ease.”",
                        textAlign: TextAlign.center,
                        style: AppFonts.text(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: tagColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for perfect 8-point star and outer breathing rings
class StarPainter extends CustomPainter {
  StarPainter({required this.isDark, required this.shineProgress, required this.ringProgress});

  final bool isDark;
  final double shineProgress;
  final double ringProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 140.0; // Scale relative to 140px viewport

    final ringColor = isDark ? const Color(0xFFE8B84B) : const Color(0xFFA0720A);

    // 1. Draw Ring 1 (inset -20px on 140px box, base radius = 70 + 20 = 90px)
    final t1 = ringProgress;
    final w1 = 0.5 - 0.5 * math.cos(t1 * 2 * math.pi);
    final scale1 = 1.0 + 0.08 * w1;
    final opacity1 = (1.0 - 0.4 * w1) * 0.08;
    final paintRing1 = Paint()
      ..color = ringColor.withValues(alpha: opacity1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;
    canvas.drawCircle(center, 90 * scale * scale1, paintRing1);

    // 2. Draw Ring 2 (inset -10px, base radius = 70 + 10 = 80px)
    final t2 = (ringProgress + 0.1667) % 1.0;
    final w2 = 0.5 - 0.5 * math.cos(t2 * 2 * math.pi);
    final scale2 = 1.0 + 0.08 * w2;
    final opacity2 = (1.0 - 0.4 * w2) * 0.12;
    final paintRing2 = Paint()
      ..color = ringColor.withValues(alpha: opacity2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;
    canvas.drawCircle(center, 80 * scale * scale2, paintRing2);

    // Save layer to clip Gloss Shine overlay
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Steel gradient linear (0,0) to (140, 140)
    final outerBladePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(140 * scale, 140 * scale),
        [
          const Color(0xFF1A1A24),
          const Color(0xFF3A3A4A),
          const Color(0xFF5A5A6A),
          const Color(0xFF3A3A4A),
          const Color(0xFF1A1A24),
        ],
        [0.0, 0.3, 0.5, 0.7, 1.0],
      );

    // Edge gradient linear (0,0) to (0,140)
    final outerEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * scale
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, 140 * scale),
        [
          Colors.white.withValues(alpha: 0.3),
          Color(0xFFB4BEC8).withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.2),
        ],
        [0.0, 0.5, 1.0],
      );

    // Steel2 gradient linear (140,0) to (0,140)
    final innerBladePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(140 * scale, 0),
        Offset(0, 140 * scale),
        [
          const Color(0xFF12121A),
          const Color(0xFF2A2A38),
          const Color(0xFF12121A),
        ],
        [0.0, 0.5, 1.0],
      );

    final innerEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3 * scale
      ..color = Colors.white.withValues(alpha: 0.08);

    // Hub gradient linear (0,0) to (140,140)
    final hubPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(140 * scale, 140 * scale),
        [
          const Color(0xFF2A2A38),
          const Color(0xFF4A4A58),
          const Color(0xFF2A2A38),
        ],
        [0.0, 0.5, 1.0],
      );

    final hubEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * scale
      ..color = Colors.white.withValues(alpha: 0.15);

    // 3. Draw Outer Star
    final outerPath = Path()
      ..moveTo(70 * scale, 0)
      ..lineTo(77 * scale, 53 * scale)
      ..lineTo(140 * scale, 70 * scale)
      ..lineTo(77 * scale, 87 * scale)
      ..lineTo(70 * scale, 140 * scale)
      ..lineTo(63 * scale, 87 * scale)
      ..lineTo(0 * scale, 70 * scale)
      ..lineTo(63 * scale, 53 * scale)
      ..close();
    canvas.drawPath(outerPath, outerBladePaint);
    canvas.drawPath(outerPath, outerEdgePaint);

    // 4. Draw Inner Star
    final innerPath = Path()
      ..moveTo(70 * scale, 18 * scale)
      ..lineTo(74 * scale, 58 * scale)
      ..lineTo(122 * scale, 70 * scale)
      ..lineTo(74 * scale, 82 * scale)
      ..lineTo(70 * scale, 122 * scale)
      ..lineTo(66 * scale, 82 * scale)
      ..lineTo(18 * scale, 70 * scale)
      ..lineTo(66 * scale, 58 * scale)
      ..close();
    canvas.drawPath(innerPath, innerBladePaint);
    canvas.drawPath(innerPath, innerEdgePaint);

    // 5. Draw Center Hub
    final gemColor = isDark ? const Color(0xFFE8B84B) : const Color(0xFFA0720A);
    canvas.drawCircle(center, 12 * scale, hubPaint);
    canvas.drawCircle(center, 12 * scale, hubEdgePaint);

    // 6. Draw Center "M" Logo Gem with drop shadow glow
    canvas.drawCircle(
      center,
      10 * scale,
      Paint()
        ..color = gemColor.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale),
    );

    // Draw stylized "M" emblem letter in center
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'M',
        style: TextStyle(
          fontSize: 13 * scale,
          fontWeight: FontWeight.w900,
          color: gemColor,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    // 7. Gloss Shine Overlay: Animated opacity linear sweep across the star
    final double sweepOffset = -100.0 + (shineProgress * 200.0);
    final shinePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx + sweepOffset - 40, center.dy + sweepOffset - 40),
        Offset(center.dx + sweepOffset + 40, center.dy + sweepOffset + 40),
        [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
        [0.0, 0.45, 0.55, 1.0],
      )
      ..blendMode = BlendMode.srcIn; // Only draw inside the star's shapes

    final shinePath = Path()
      ..moveTo(70 * scale, 2 * scale)
      ..lineTo(76 * scale, 54 * scale)
      ..lineTo(138 * scale, 70 * scale)
      ..lineTo(76 * scale, 86 * scale)
      ..lineTo(70 * scale, 138 * scale)
      ..lineTo(64 * scale, 86 * scale)
      ..lineTo(2 * scale, 70 * scale)
      ..lineTo(64 * scale, 54 * scale)
      ..close();
    canvas.drawPath(shinePath, shinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.shineProgress != shineProgress ||
        oldDelegate.ringProgress != ringProgress;
  }
}

// Orbiting Sparkle Widget (matching CSS pulse & delay)
class OrbitSparkle extends StatefulWidget {
  const OrbitSparkle({super.key, required this.dx, required this.dy, required this.delay});

  final double dx;
  final double dy;
  final Duration delay;

  @override
  State<OrbitSparkle> createState() => _OrbitSparkleState();
}

class _OrbitSparkleState extends State<OrbitSparkle> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(widget.delay, () {
      if (mounted) {
        _controller = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 2),
        )..repeat();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final progress = _controller!.value;
        double scale = 0.0;
        double opacity = 0.0;
        
        // Match @keyframes sparkPulse
        if (progress < 0.3) {
          final t = progress / 0.3;
          scale = t;
          opacity = t;
        } else {
          final t = (progress - 0.3) / 0.7;
          scale = 1.0 - t;
          opacity = 1.0 - t;
        }

        return Positioned(
          left: 100 + widget.dx - 2.0, // 100 is center of width (200 / 2)
          top: 100 + widget.dy - 2.0,  // 100 is center of height (200 / 2)
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PulseMPainter extends CustomPainter {
  PulseMPainter({
    required this.progress,
    required this.pulse,
    required this.isDark,
  });

  final double progress;
  final double pulse;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Define 5 key vertices matching Pulse M growth chart geometry
    final p0 = Offset(w * 0.10, h * 0.85); // Start bottom-left
    final p1 = Offset(w * 0.32, h * 0.30); // Top-left peak
    final p2 = Offset(w * 0.50, h * 0.65); // Valley dip
    final p3 = Offset(w * 0.68, h * 0.15); // Highest surge peak
    final p4 = Offset(w * 0.90, h * 0.85); // End bottom-right

    final points = [p0, p1, p2, p3, p4];

    final colorTeal = const Color(0xFF00C896);
    final colorGold = const Color(0xFFE8B84B);
    final colorPurple = const Color(0xFFEC4899);
    final colorBlue = const Color(0xFF3B82F6);

    final fullPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy);

    final pm = fullPath.computeMetrics().first;
    final totalLen = pm.length;
    final drawLen = (progress.clamp(0.0, 1.0)) * totalLen;
    final linePath = pm.extractPath(0.0, drawLen);

    // 1. Draw glowing ambient line shadow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    glowPaint.shader = ui.Gradient.linear(
      p0,
      p4,
      [
        colorTeal.withValues(alpha: 0.4),
        colorGold.withValues(alpha: 0.4),
        colorPurple.withValues(alpha: 0.4),
        colorBlue.withValues(alpha: 0.4),
      ],
      [0.0, 0.35, 0.70, 1.0],
    );
    canvas.drawPath(linePath, glowPaint);

    // 2. Draw Main Solid Gradient Stroke
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        p0,
        p4,
        [colorTeal, colorGold, colorPurple, colorBlue],
        [0.0, 0.35, 0.70, 1.0],
      );

    canvas.drawPath(linePath, mainPaint);

    // 3. Draw Vertex Nodes (Glowing Dots pop in as line reaches them)
    final nodeColors = [colorTeal, colorTeal, colorGold, colorPurple, colorBlue];
    final nodeSizes = [4.5, 6.5, 5.5, 8.5, 5.5];
    final nodeDistances = [0.0, 0.25 * totalLen, 0.5 * totalLen, 0.75 * totalLen, totalLen];

    for (int i = 0; i < points.length; i++) {
      if (drawLen < nodeDistances[i] * 0.9) continue; // Only show nodes when path reaches them

      final p = points[i];
      final col = nodeColors[i];
      final r = nodeSizes[i];

      // Outer node glow
      canvas.drawCircle(
        p,
        r + 5,
        Paint()
          ..color = col.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Inner node dot
      canvas.drawCircle(p, r, Paint()..color = Colors.white);
      canvas.drawCircle(p, r * 0.6, Paint()..color = col);
    }

    // 4. Draw Animated Pulsing Aura Ring around Highest Peak (p3)
    if (drawLen >= nodeDistances[3] * 0.9) {
      final pulseScale = 1.0 + (pulse * 0.8);
      final pulseOpacity = (1.0 - pulse) * 0.6;
      canvas.drawCircle(
        p3,
        14.0 * pulseScale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = colorPurple.withValues(alpha: pulseOpacity),
      );
    }

    // 5. Draw Laser Energy Tip traveling at the head of the drawn line
    final tangent = pm.getTangentForOffset(drawLen > 0 ? drawLen : 0.1);
    if (tangent != null && drawLen < totalLen) {
      final wavePos = tangent.position;
      canvas.drawCircle(
        wavePos,
        9.0,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        wavePos,
        5.0,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PulseMPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isDark != isDark;
  }
}
