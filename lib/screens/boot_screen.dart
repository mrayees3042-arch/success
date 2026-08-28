import '../core/app_fonts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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

    // 1. App Launch sound
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
        final firstBootCompleted = prefs.getBool('first_boot_completed') ?? false;
        final hasUserSavedData = (name != null && name.trim().isNotEmpty) ||
            prefs.containsKey('user_dob') ||
            prefs.containsKey('life_plan_goals') ||
            prefs.containsKey('bluetooth_last_backup_at');
        final isConfigured = firstBootCompleted || hasUserSavedData;

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
