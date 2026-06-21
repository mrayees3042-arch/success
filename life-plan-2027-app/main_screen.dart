import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';

// === COLORS ===
const Color bg = Color(0xFF06060F);
const Color gold = Color(0xFFE8B84B);
const Color gold2 = Color(0xFFFFD580);
const Color gold3 = Color(0xFFB8861E);
const Color emerald = Color(0xFF00C896);
const Color azure = Color(0xFF38BDF8);
const Color rose = Color(0xFFF87171);
const Color textColor = Color(0xFFF2F2FF);
const Color sub = Color(0xFF7070A0);
const Color sub2 = Color(0xFF9090BB);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _orbController;
  late AnimationController _pulseController;

  bool isToggled = true;
  int _waterGlasses = 2;

  // Mock prayer states
  final List<String> _prayerStates = [
    'missed',
    'missed',
    'missed',
    'pending',
    'active',
    'pending',
    'pending',
    'ghost',
  ];

  // Task states
  bool _task1Done = false;
  bool _task2Done = false;

  // --- LOGIC CALCULATIONS ---
  double get _prayerProgress =>
      _prayerStates.where((s) => s == 'done').length / 7;
  double get _taskProgress =>
      ([_task1Done, _task2Done].where((t) => t).length) /
      5; // Design spec expects 5
  double get _waterProgress => _waterGlasses / 10;

  int get _totalScore {
    double score = 0;
    score += _prayerProgress * 50;
    score += _taskProgress * 30;
    score += _waterProgress * 20;
    return score.round();
  }

  void _togglePrayer(int index) {
    setState(() {
      String current = _prayerStates[index];
      if (current == 'missed') {
        _prayerStates[index] = 'done';
      } else if (current == 'done') {
        _prayerStates[index] = 'missed';
      } else if (current == 'active' || current == 'pending') {
        _prayerStates[index] = 'done';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _orbController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _staggeredFade(Widget child, int index) {
    final start = index * 0.12;
    final end = (start + 0.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final curve = CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );

        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curve.value)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. Base BG & Gradients
          Container(color: bg),
          _buildRadialGradients(),

          // 2. Geometric Pattern
          const Opacity(
            opacity: 0.025,
            child: CustomPaint(
              painter: StarPatternPainter(),
              size: Size.infinite,
            ),
          ),

          // 3. Floating Orbs
          _buildFloatingOrbs(),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildTopBar(),
                  _staggeredFade(_buildHero(), 0),
                  _staggeredFade(_buildCountdownCard(), 1),
                  _staggeredFade(_buildAyahCard(), 2),
                  _staggeredFade(_buildMetricsRow(context), 3),
                  _staggeredFade(_buildScoreCard(), 4),
                  _buildSectionHeader("Prayers Progress"),
                  _staggeredFade(_buildNextPrayerBanner(), 5),
                  _staggeredFade(_buildPrayerGrid(), 6),
                  _buildSectionHeader("Daily Tasks", showButton: true),
                  _staggeredFade(_buildTasks(), 7),
                  _staggeredFade(_buildWaterIntakeCard(), 8),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom Nav
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildRadialGradients() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: 0,
          right: 0,
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  const Color(0xFFB4821E).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00C896).withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingOrbs() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        final offset = Offset(0, -30 * _orbController.value);
        return Stack(
          children: [
            _positionedOrb(
              300,
              gold.withValues(alpha: 0.08),
              offset,
              top: -50,
              left: -50,
            ),
            _positionedOrb(
              250,
              emerald.withValues(alpha: 0.07),
              offset,
              left: -50,
              bottom: -50,
            ),
            _positionedOrb(
              200,
              azure.withValues(alpha: 0.05),
              offset,
              top: 300,
              left: 100,
            ),
          ],
        );
      },
    );
  }

  Widget _positionedOrb(
    double size,
    Color color,
    Offset offset, {
    double? top,
    double? left,
    double? right,
    double? bottom,
  }) {
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          right: right,
          bottom: bottom,
          child: Transform.translate(
            offset: offset,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            children: [
              Text(
                'بِسْمِ اللَّه',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  color: gold,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(color: gold.withValues(alpha: 0.5), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => isToggled = !isToggled),
            child: Container(
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [gold3, gold]),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isToggled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, gold2, Colors.white],
              stops: [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Text(
              'Rayees',
              style: GoogleFonts.syne(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'مُتَّقِين',
                  style: GoogleFonts.amiri(fontSize: 13, color: gold),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'MUTTAQIN',
                  style: GoogleFonts.syne(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gold.withValues(alpha: 0.1), gold.withValues(alpha: 0.03)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '217',
                style: GoogleFonts.syne(
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  color: gold2,
                  letterSpacing: -3,
                  shadows: [const Shadow(color: gold, blurRadius: 30)],
                ),
              ),
              Text(
                'DAYS TO 2027',
                style: GoogleFonts.syne(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                  color: sub2,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [gold.withValues(alpha: 0.3), Colors.transparent],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '٢٠٢٦ · ١٤٤٧ هـ',
                style: GoogleFonts.syne(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: gold.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '28 May 2026',
                style: GoogleFonts.dmSans(fontSize: 12, color: sub2),
              ),
              Text(
                'Thursday',
                style: GoogleFonts.syne(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAyahCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: azure.withValues(alpha: 0.12)),
        gradient: LinearGradient(
          colors: [
            azure.withValues(alpha: 0.06),
            azure.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Stack(
        children: [
          Text(
            '❝',
            style: TextStyle(
              fontSize: 28,
              color: azure.withValues(alpha: 0.15),
            ),
          ),
          Column(
            children: [
              const SizedBox(width: double.infinity),
              Text(
                'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
                style: GoogleFonts.amiri(fontSize: 21, color: gold2),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 5),
              Text(
                'Indeed Allah is with the patient.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: sub2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '◆ Quran 2:153 ◆',
                style: GoogleFonts.syne(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: azure.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _metricCard(
              'Prayers',
              '${_prayerStates.where((s) => s == 'done').length}/7',
              gold,
              _prayerProgress,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricCard(
              'Tasks',
              '${[_task1Done, _task2Done].where((t) => t).length}/5',
              emerald,
              _taskProgress,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricCard(
              'Water',
              '${(_waterGlasses * 0.26).toStringAsFixed(1)}L',
              azure,
              _waterProgress,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF191632), Color(0xFF0F0D20)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              painter: ProgressRingPainter(progress: progress, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.syne(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withValues(alpha: 0.14)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1630), Color(0xFF0E0B1C)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(
              painter: ScoreRingPainter(progress: _totalScore / 100),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _totalScore.toString(),
                      style: GoogleFonts.syne(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: gold2,
                        shadows: [const Shadow(color: gold, blurRadius: 15)],
                      ),
                    ),
                    Text(
                      '/100',
                      style: GoogleFonts.syne(
                        fontSize: 8,
                        color: sub,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Score',
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  'Complete prayers & tasks to level up',
                  style: GoogleFonts.dmSans(fontSize: 10, color: sub),
                ),
                const SizedBox(height: 10),
                _scoreRow('Prayers', gold, _prayerProgress),
                _scoreRow('Tasks', emerald, _taskProgress),
                _scoreRow('Water', azure, _waterProgress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreRow(String label, Color color, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: sub2),
            ),
          ),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.syne(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, {bool showButton = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.syne(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: sub,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (showButton) ...[
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [gold, gold3]),
                boxShadow: [
                  BoxShadow(color: gold, blurRadius: 10, spreadRadius: -2),
                ],
              ),
              child: const Center(
                child: Text(
                  '+',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextPrayerBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: emerald.withValues(alpha: 0.2)),
        gradient: LinearGradient(
          colors: [
            emerald.withValues(alpha: 0.1),
            emerald.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT PRAYER',
                style: GoogleFonts.syne(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: emerald.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Asr ',
                    style: GoogleFonts.syne(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'عَصْر',
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      color: emerald.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '3:45 PM',
                style: GoogleFonts.syne(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: emerald,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                      color: emerald.withValues(alpha: 0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
              Text(
                'in 2h 22m · on time',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: emerald.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerGrid() {
    final prayers = [
      ('Tahajjud', 'تَهَجُّد'),
      ('Fajr', 'فَجْر'),
      ('Dhuha', 'ضُحَى'),
      ('Dhuhr', 'ظُهْر'),
      ('Asr', 'عَصْر'),
      ('Maghrib', 'مَغْرِب'),
      ('Isha', 'عِشَاء'),
      ('', ''),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: 8,
        itemBuilder: (context, i) {
          if (i == 7) {
            return const SizedBox.shrink();
          }
          return GestureDetector(
            onTap: () => _togglePrayer(i),
            child: _prayerCell(prayers[i].$1, prayers[i].$2, _prayerStates[i]),
          );
        },
      ),
    );
  }

  Widget _prayerCell(String eng, String ar, String state) {
    Color cellColor;
    Color statusColor;
    String icon;
    bool isPulse = state == 'active';

    switch (state) {
      case 'missed':
        cellColor = rose;
        statusColor = rose;
        icon = '✕';
        break;
      case 'done':
        cellColor = emerald;
        statusColor = emerald;
        icon = '✓';
        break;
      case 'active':
        cellColor = gold;
        statusColor = gold;
        icon = '◆';
        break;
      default:
        cellColor = Colors.white.withValues(alpha: 0.09);
        statusColor = Colors.white.withValues(alpha: 0.12);
        icon = '○';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cellColor.withValues(alpha: state == 'pending' ? 0.09 : 0.25),
        ),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [cellColor.withValues(alpha: 0.08), Colors.transparent],
        ),
        boxShadow: isPulse
            ? [
                BoxShadow(
                  color: gold.withValues(alpha: 0.3 * _pulseController.value),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ar, style: GoogleFonts.amiri(fontSize: 15, color: textColor)),
          Text(
            eng,
            style: GoogleFonts.syne(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: sub,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            icon,
            style: TextStyle(
              fontSize: 14,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasks() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _taskCell(
            'Quran Reading',
            'after Fajr',
            _task1Done,
            (v) => setState(() => _task1Done = v),
          ),
          const SizedBox(height: 8),
          _taskCell(
            'Productive Phone',
            'Use phone only for useful work',
            _task2Done,
            (v) => setState(() => _task2Done = v),
          ),
        ],
      ),
    );
  }

  Widget _taskCell(
    String title,
    String subT,
    bool done,
    Function(bool) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!done),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF18142E), Color(0xFF0E0C1E)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? emerald : Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                color: done ? emerald : Colors.transparent,
              ),
              child: done
                  ? const Center(
                      child: Text(
                        '✓',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subT,
                    style: GoogleFonts.dmSans(fontSize: 11, color: sub),
                  ),
                ],
              ),
            ),
            const Opacity(
              opacity: 0.5,
              child: Text('✏', style: TextStyle(color: sub, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterIntakeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ).copyWith(bottom: 110),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: azure.withValues(alpha: 0.12)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12162E), Color(0xFF0A0E1E)],
        ),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 28)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: (_waterGlasses * 0.26).toStringAsFixed(1),
                          style: GoogleFonts.syne(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: azure,
                            shadows: [
                              const Shadow(color: azure, blurRadius: 10),
                            ],
                          ),
                        ),
                        WidgetSpan(
                          child: Transform.translate(
                            offset: const Offset(2, -10),
                            child: Text(
                              'L',
                              style: GoogleFonts.syne(fontSize: 12, color: sub),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'of 2.6 L goal today',
                    style: GoogleFonts.dmSans(fontSize: 11, color: sub),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$_waterGlasses ',
                          style: GoogleFonts.syne(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        TextSpan(
                          text: '/ 10 glasses',
                          style: GoogleFonts.syne(fontSize: 11, color: sub),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '260 ml per glass',
                    style: GoogleFonts.dmSans(fontSize: 10, color: sub),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width:
                    (MediaQuery.of(context).size.width - 68) * _waterProgress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [azure, Color(0xFF7DD3FC)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: 10,
            itemBuilder: (context, i) => _glassCell(i + 1, i < _waterGlasses),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap a glass to log · 260 ml each',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: azure.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCell(int n, bool isFull) {
    return GestureDetector(
      onTap: () => setState(() => _waterGlasses = isFull ? n - 1 : n),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 38,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                  bottom: Radius.circular(9),
                ),
                border: Border.all(
                  color: isFull
                      ? azure.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1.5,
                ),
                color: Colors.white.withValues(alpha: 0.02),
                boxShadow: isFull
                    ? [
                        const BoxShadow(
                          color: azure,
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (isFull)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: isFull ? 34 : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [azure, Color(0xFF7DD3FC)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            n.toString(),
            style: GoogleFonts.syne(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem('🏠', 'Today', active: true),
              _navItem('📋', 'Habits'),
              _navItem('💪', 'Workout'),
              _navItem('💰', 'Income'),
              _navItem('📌', 'Plan'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(String icon, String label, {bool active = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 21)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.syne(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: active ? gold : sub,
          ),
        ),
        if (active) ...[
          const SizedBox(height: 4),
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: gold,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: gold, blurRadius: 5)],
            ),
          ),
        ],
      ],
    );
  }
}

// Custom Painters
class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paintBase = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final paintProgress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paintBase);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paintProgress,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class ScoreRingPainter extends CustomPainter {
  final double progress;
  ScoreRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base Ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    // Dashed Ring
    final dashPaint = Paint()
      ..color = gold.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    for (double i = 0; i < 2 * math.pi; i += 0.3) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i,
        0.1,
        false,
        dashPaint,
      );
    }

    // Progress Arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [gold, gold2],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class StarPatternPainter extends CustomPainter {
  const StarPatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (double x = 0; x < size.width; x += 40) {
      for (double y = 0; y < size.height; y += 40) {
        _drawStar(canvas, Offset(x, y), paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      double angle = i * math.pi / 4;
      double r = (i % 2 == 0) ? 3 : 1;
      path.lineTo(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
