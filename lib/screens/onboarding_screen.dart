import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:success/main.dart';
import 'package:success/providers/theme_provider.dart';
import 'package:success/services/haptic_service.dart';
import 'package:success/services/sound_manager.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _nameController = TextEditingController();
  DateTime _selectedDob = DateTime(2000, 1, 1);
  int _selectedGoalYear = 2027;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  void _nextPage() {
    HapticService.tapFeedback();
    SoundManager.playTapClick();
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSetup();
    }
  }

  void _prevPage() {
    HapticService.tapFeedback();
    SoundManager.playTapClick();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectDob(BuildContext context, bool isDark) async {
    HapticService.tapFeedback();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF00C896),
                    onPrimary: Colors.white,
                    surface: Color(0xFF161922),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF00C896),
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _completeSetup() async {
    HapticService.heavy();
    SoundManager.playTapClick();

    final prefs = await SharedPreferences.getInstance();
    final name = _nameController.text.trim();
    final dobStr =
        '${_selectedDob.year}-${_selectedDob.month.toString().padLeft(2, '0')}-${_selectedDob.day.toString().padLeft(2, '0')}';

    await prefs.setString('user_name', name);
    await prefs.setString('user_dob', dobStr);
    await prefs.setInt('user_goal_year', _selectedGoalYear);
    await prefs.setInt('user_goal_month', 1);
    await prefs.setInt('user_goal_day', 1);
    await prefs.setBool('first_boot_completed', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDark;

    final bgColor = isDark ? const Color(0xFF0A0C10) : const Color(0xFFF8F6F0);
    final cardBg = isDark ? const Color(0xFF141720) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : const Color(0xFF1E232A);
    final textMuted = isDark ? const Color(0xFF8A909A) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Indicator Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    GestureDetector(
                      onTap: _prevPage,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: textColor,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 36, height: 36),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isActive = index == _currentStep;
                        final isPassed = index < _currentStep;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive || isPassed
                                ? const Color(0xFF00C896)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 36, height: 36),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentStep = page);
                },
                children: [
                  _buildWelcomeStep(textColor, textMuted, cardBg, borderColor, isDark),
                  _buildNameStep(textColor, textMuted, cardBg, borderColor, isDark),
                  _buildDobStep(context, textColor, textMuted, cardBg, borderColor, isDark),
                  _buildGoalStep(textColor, textMuted, cardBg, borderColor, isDark),
                ],
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: _nextPage,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C896), Color(0xFF25A35A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C896).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _currentStep == 0
                        ? 'GET STARTED →'
                        : (_currentStep == 3 ? 'COMPLETE SETUP 🎉' : 'CONTINUE →'),
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(
    Color textColor,
    Color textMuted,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF00C896).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00C896).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 40,
              color: Color(0xFF00C896),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Muttaqin',
            style: GoogleFonts.syne(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your personal life odometer, habit tracker, and workout companion.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF00C896), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '100% Offline & Private · Zero tracking or registration required.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep(
    Color textColor,
    Color textMuted,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    final previewName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim().toUpperCase()
        : 'YOUR NAME';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What is your name?',
            style: GoogleFonts.syne(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This will personalize your splash screen and dashboard experience.',
            style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: 28),

          // Name Input Field
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00C896), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter your name (e.g. Rayees)',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: textMuted.withValues(alpha: 0.6),
                ),
                icon: const Icon(Icons.person_outline, color: Color(0xFF00C896)),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Live Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Text(
                  'SPLASH PREVIEW',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'BUILT FOR',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  previewName,
                  style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: const Color(0xFF00C896),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDobStep(
    BuildContext context,
    Color textColor,
    Color textMuted,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    final age = _calculateAge(_selectedDob);
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final formattedDob =
        '${_selectedDob.day} ${monthNames[_selectedDob.month - 1]} ${_selectedDob.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'When were you born?',
            style: GoogleFonts.syne(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Date of Birth powers the exact Life Odometer countdown.',
            style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: 28),

          // Date Picker Button Trigger
          GestureDetector(
            onTap: () => _selectDob(context, isDark),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00C896), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: Color(0xFF00C896), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date of Birth',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDob,
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined, color: Color(0xFF00C896)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Calculated Age Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00C896).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00C896).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFF00C896), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT AGE PREVIEW',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: const Color(0xFF00C896),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$age Years Old',
                        style: GoogleFonts.syne(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep(
    Color textColor,
    Color textMuted,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    final years = [2027, 2028, 2030];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Target Horizon',
            style: GoogleFonts.syne(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your primary milestone year for daily progress tracking.',
            style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: 28),

          Column(
            children: years.map((year) {
              final isSelected = _selectedGoalYear == year;
              return GestureDetector(
                onTap: () {
                  HapticService.tapFeedback();
                  setState(() => _selectedGoalYear = year);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00C896).withValues(alpha: 0.12)
                        : cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00C896)
                          : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected
                            ? const Color(0xFF00C896)
                            : textMuted,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Goal Year $year',
                        style: GoogleFonts.syne(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF00C896)
                              : textColor,
                        ),
                      ),
                      const Spacer(),
                      if (year == 2027)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C896),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
