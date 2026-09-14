import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../core/app_fonts.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';

class SubTask {
  String id;
  String title;
  bool isDone;

  SubTask({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
  };

  factory SubTask.fromJson(Map<String, dynamic> json) => SubTask(
    id: json['id'] as String,
    title: json['title'] as String,
    isDone: json['isDone'] as bool? ?? false,
  );
}

class LifeGoal {
  String id;
  String title;
  String deadline;
  double progress;
  Color color;
  bool isDone;
  String section; // 'left' (Out of My Control / Let Go) or 'right' (In My Control / I Can Do)
  List<SubTask> subTasks;

  LifeGoal({
    required this.id,
    required this.title,
    required this.deadline,
    required this.progress,
    required this.color,
    this.isDone = false,
    this.section = 'right',
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'deadline': deadline,
    'progress': progress,
    'color': color.toARGB32(),
    'isDone': isDone,
    'section': section,
    'subTasks': subTasks.map((t) => t.toJson()).toList(),
  };

  factory LifeGoal.fromJson(Map<String, dynamic> json) => LifeGoal(
    id: json['id'] as String,
    title: json['title'] as String,
    deadline: json['deadline'] as String,
    progress: (json['progress'] as num).toDouble(),
    color: Color(json['color'] as int),
    isDone: json['isDone'] as bool? ?? false,
    section: (json['section'] as String?) ?? 'right',
    subTasks: (json['subTasks'] as List?)
        ?.map((t) => SubTask.fromJson(t as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class LifePlanScreen extends StatefulWidget {
  const LifePlanScreen({
    super.key,
    required this.theme,
    this.onScreenshot,
    required this.userGoalYear,
  });
  final ThemeColors theme;
  final VoidCallback? onScreenshot;
  final int userGoalYear;

  @override
  State<LifePlanScreen> createState() => _LifePlanScreenState();
}

class _LifePlanScreenState extends State<LifePlanScreen> {
  List<LifeGoal> _goals = [];
  bool _isLoading = true;
  String _selectedSection = 'right'; // 'left' = Out of Control (Let Go), 'right' = In My Control (I Can Do)
  final Set<String> _expandedGoalIds = {};

  void _toggleGoalCompletion(LifeGoal goal) {
    HapticService.habitComplete(!goal.isDone);
    setState(() {
      goal.isDone = !goal.isDone;
      if (goal.isDone) {
        goal.progress = 1.0;
        for (var t in goal.subTasks) {
          t.isDone = true;
        }
        AudioService.playAllHabitsDone();
      } else {
        goal.progress = 0.0;
        for (var t in goal.subTasks) {
          t.isDone = false;
        }
        AudioService.playHabitComplete();
      }
    });
    _saveGoals();
  }

  void _toggleSubTask(LifeGoal goal, SubTask subtask) {
    HapticService.selection();
    AudioService.playHabitComplete();
    setState(() {
      subtask.isDone = !subtask.isDone;
      if (goal.subTasks.isNotEmpty) {
        final doneCount = goal.subTasks.where((t) => t.isDone).length;
        goal.progress = doneCount / goal.subTasks.length;
        goal.isDone = doneCount == goal.subTasks.length;
      }
    });
    _saveGoals();
  }

  void _addSubTask(LifeGoal goal, String title) {
    if (title.isEmpty) return;
    HapticService.medium();
    setState(() {
      final sub = SubTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
      );
      goal.subTasks.add(sub);
      final doneCount = goal.subTasks.where((t) => t.isDone).length;
      goal.progress = doneCount / goal.subTasks.length;
      goal.isDone = doneCount == goal.subTasks.length;
    });
    _saveGoals();
  }

  void _deleteSubTask(LifeGoal goal, SubTask subtask) {
    HapticService.medium();
    setState(() {
      goal.subTasks.remove(subtask);
      if (goal.subTasks.isNotEmpty) {
        final doneCount = goal.subTasks.where((t) => t.isDone).length;
        goal.progress = doneCount / goal.subTasks.length;
        goal.isDone = doneCount == goal.subTasks.length;
      } else {
        goal.progress = goal.isDone ? 1.0 : 0.0;
      }
    });
    _saveGoals();
  }

  void _moveGoalSection(LifeGoal goal, String targetSection) {
    HapticService.medium();
    AudioService.playHabitComplete();
    setState(() {
      goal.section = targetSection;
    });
    _saveGoals();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          targetSection == 'left'
              ? 'Moved to Left Section (Out of Control — Let Go) 🍃'
              : 'Moved to Right Section (In My Control — Actionable) ⚡',
          style: AppFonts.text(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: targetSection == 'left' ? const Color(0xFF334155) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final String? goalsJson = prefs.getString('life_plan_goals');

    if (goalsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(goalsJson);
        final loadedGoals = decoded.map((e) => LifeGoal.fromJson(e)).toList();
        final defaultTitles = [
          'Autonexuz Brand',
          'Upwork Profile',
          'Sunnah Consistency',
          'Fitness Goal',
        ];
        final containsOnlyDefaultFocusAreas =
            loadedGoals.length == defaultTitles.length &&
            List.generate(
              defaultTitles.length,
              (index) => loadedGoals[index].title == defaultTitles[index],
            ).every((matches) => matches);
        if (mounted) {
          setState(() {
            _goals = containsOnlyDefaultFocusAreas ? [] : loadedGoals;
            _isLoading = false;
          });
        }
        if (containsOnlyDefaultFocusAreas) {
          await _saveGoals();
        }
      } catch (e) {
        _setDefaults();
      }
    } else {
      _setDefaults();
    }
  }

  Future<void> _setDefaults() async {
    if (!mounted) return;
    setState(() {
      _goals = [];
      _isLoading = false;
    });
    _saveGoals();
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_goals.map((g) => g.toJson()).toList());
    await prefs.setString('life_plan_goals', encoded);
  }

  void _deleteGoal(LifeGoal goal) {
    setState(() {
      _goals.remove(goal);
    });
    _saveGoals();
  }

  void _showAddGoalSheet({String? defaultSection}) {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    String section = defaultSection ?? _selectedSection;
    double progressVal = 0.0;
    Color selectedColor = section == 'left' ? const Color(0xFF38BDF8) : kBlue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, setSheetState) {
            final isLeft = section == 'left';
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isLeft ? 'Dump Idea / Thought 🍃' : 'Add Actionable Goal ⚡',
                        style: AppFonts.display(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.theme.text1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isLeft
                              ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                              : const Color(0xFF00C896).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isLeft ? 'Left Section' : 'Right Section',
                          style: AppFonts.text(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isLeft ? const Color(0xFF38BDF8) : const Color(0xFF00C896),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section Choice Switcher
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: widget.theme.isDark ? const Color(0xFF131320) : const Color(0xFFE5E0D8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                section = 'left';
                                selectedColor = const Color(0xFF38BDF8);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isLeft
                                    ? (widget.theme.isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '🍃 Left (Out of Control)',
                                  style: AppFonts.text(
                                    fontSize: 12,
                                    fontWeight: isLeft ? FontWeight.w700 : FontWeight.w500,
                                    color: isLeft ? widget.theme.text1 : widget.theme.text3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                section = 'right';
                                selectedColor = kBlue;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isLeft
                                    ? (widget.theme.isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '⚡ Right (I Can Do)',
                                  style: AppFonts.text(
                                    fontSize: 12,
                                    fontWeight: !isLeft ? FontWeight.w700 : FontWeight.w500,
                                    color: !isLeft ? widget.theme.text1 : widget.theme.text3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: AppFonts.text(color: widget.theme.text1, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: isLeft ? 'Idea / Thought to dump' : 'Goal Title',
                      hintText: isLeft
                          ? 'e.g. Market trend, someone\'s reaction, future uncertainty...'
                          : 'e.g. Master Flutter, build app feature...',
                      hintStyle: AppFonts.text(color: widget.theme.text3.withValues(alpha: 0.6), fontSize: 13),
                      labelStyle: AppFonts.text(color: widget.theme.text3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isLeft ? const Color(0xFF38BDF8) : kGold,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: dateCtrl,
                    style: AppFonts.text(color: widget.theme.text1, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: isLeft ? 'Optional Note / Context' : 'Target Date (e.g. Dec 2026)',
                      labelStyle: AppFonts.text(color: widget.theme.text3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isLeft ? const Color(0xFF38BDF8) : kGold,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      kBlue,
                      kGold,
                      kGreen,
                      kTeal,
                      const Color(0xFFf97316),
                      kRed,
                    ].map((c) {
                      return GestureDetector(
                        onTap: () {
                          if (mounted) {
                            setSheetState(() => selectedColor = c);
                          }
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == c
                                  ? widget.theme.text1
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLeft ? const Color(0xFF38BDF8) : kGold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final deadline = dateCtrl.text.trim().isEmpty
                            ? (isLeft ? 'Let Go & Parked' : 'Ongoing')
                            : dateCtrl.text.trim();
                        if (title.isEmpty) return;
                        final goal = LifeGoal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          deadline: deadline,
                          progress: progressVal,
                          color: selectedColor,
                          section: section,
                        );

                        FocusScope.of(sheetContext).unfocus();
                        titleCtrl.clear();
                        dateCtrl.clear();
                        Navigator.pop(sheetContext);

                        HapticService.medium();
                        AudioService.playLaunch();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _goals.add(goal);
                              _selectedSection = section;
                            });
                            _saveGoals();
                          }
                        });
                      },
                      child: Text(
                        isLeft ? 'Dump to Left Section 🍃' : 'Add to Right Section ⚡',
                        style: AppFonts.display(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = theme.isDark;
    final bgColor = isDark ? const Color(0xFF06060F) : const Color(0xFFF5F0E8);
    final cardBg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x12000000);

    final goldColor = isDark ? const Color(0xFFE8B84B) : const Color(0xFFA0720A);
    final emeraldColor = isDark ? const Color(0xFF00C896) : const Color(0xFF0A7A5A);
    final azureColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF1565A0);
    final purpleColor = isDark ? const Color(0xFFA855F7) : const Color(0xFF7C3AED);
    final redColor = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC0392B);

    final text1 = theme.text1;
    final text2 = theme.text2;
    final text3 = theme.text3;

    final leftGoals = _goals.where((g) => g.section == 'left').toList();
    final rightGoals = _goals.where((g) => g.section != 'left').toList();

    final currentSectionGoals = _selectedSection == 'left' ? leftGoals : rightGoals;
    final activeGoals = currentSectionGoals.where((g) => !g.isDone).toList();
    final completedGoals = currentSectionGoals.where((g) => g.isDone).toList();

    // Section Selector Widget
    Widget buildSectionSwitcher() {
      final isLeft = _selectedSection == 'left';
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131320) : const Color(0xFFE8E2D8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 0.5),
        ),
        child: Row(
          children: [
            // Left Section Tab (Out of Control / Let Go)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticService.selection();
                  setState(() => _selectedSection = 'left');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isLeft
                        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isLeft
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🍃', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Left (Let Go)',
                          style: AppFonts.text(
                            fontSize: 12.5,
                            fontWeight: isLeft ? FontWeight.w700 : FontWeight.w500,
                            color: isLeft ? text1 : text3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (leftGoals.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: azureColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${leftGoals.length}',
                            style: AppFonts.compact(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: azureColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Right Section Tab (In My Control / I Can Do)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticService.selection();
                  setState(() => _selectedSection = 'right');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !isLeft
                        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: !isLeft
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Right (I Can Do)',
                          style: AppFonts.text(
                            fontSize: 12.5,
                            fontWeight: !isLeft ? FontWeight.w700 : FontWeight.w500,
                            color: !isLeft ? text1 : text3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rightGoals.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: emeraldColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${rightGoals.length}',
                            style: AppFonts.compact(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: emeraldColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Explanatory Section Banner
    Widget buildSectionBanner() {
      final isLeft = _selectedSection == 'left';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isLeft
              ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : const Color(0xFFE2E8F0))
              : emeraldColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLeft ? azureColor.withValues(alpha: 0.25) : emeraldColor.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isLeft ? '🍃' : '⚡', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLeft
                        ? 'OUT OF MY CONTROL (PARKED & LET GO)'
                        : 'IN MY CONTROL (ACTIONABLE GOALS)',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isLeft ? azureColor : emeraldColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isLeft
                        ? 'Dump ideas, thoughts, and external outcomes here. You cannot control them, so zero stress — no need to worry.'
                        : 'Things you can do yourself. Focus your daily energy, steps, and execution here.',
                    style: AppFonts.text(
                      fontSize: 12.5,
                      color: text2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Empty state helper
    Widget buildEmptyState() {
      final isLeft = _selectedSection == 'left';
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (isLeft ? azureColor : emeraldColor).withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isLeft ? azureColor : emeraldColor).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                isLeft ? Icons.spa_rounded : Icons.flag_rounded,
                size: 30,
                color: isLeft ? azureColor : emeraldColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLeft ? 'Left Section is Clear' : 'No Actionable Goals Yet',
              style: AppFonts.display(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLeft
                  ? 'Have worries, external factors, or uncontrollable thoughts? Dump them here to free your mind.'
                  : 'Add goals and milestones that you can take action on yourself.',
              style: AppFonts.text(
                fontSize: 13,
                color: text3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => _showAddGoalSheet(defaultSection: _selectedSection),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLeft
                        ? [azureColor, const Color(0xFF0284C7)]
                        : [emeraldColor, const Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isLeft ? azureColor : emeraldColor).withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isLeft ? 'Dump to Left Section' : 'Add to Right Section',
                        style: AppFonts.text(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Goal / Dump Card Builder
    Widget buildGoalCard(LifeGoal goal) {
      final isCompleted = goal.isDone;
      final expanded = _expandedGoalIds.contains(goal.id);
      final isLeft = goal.section == 'left';

      final accentGradient = isLeft
          ? LinearGradient(colors: [azureColor, const Color(0xFF64748B)])
          : (isCompleted
              ? LinearGradient(colors: [emeraldColor, goldColor])
              : LinearGradient(colors: [emeraldColor, purpleColor]));

      final progressGradient = isCompleted
          ? LinearGradient(colors: [emeraldColor, goldColor])
          : LinearGradient(colors: [isLeft ? azureColor : emeraldColor, purpleColor]);

      final pillBg = isLeft
          ? azureColor.withValues(alpha: 0.12)
          : (isCompleted ? emeraldColor.withValues(alpha: 0.12) : goldColor.withValues(alpha: 0.12));
      final pillBorder = isLeft
          ? azureColor.withValues(alpha: 0.3)
          : (isCompleted ? emeraldColor.withValues(alpha: 0.3) : goldColor.withValues(alpha: 0.3));
      final pillText = isLeft ? azureColor : (isCompleted ? emeraldColor : goldColor);
      final pillLabel = isLeft ? 'LET GO' : (isCompleted ? 'DONE' : 'ACTIONABLE');

      double progressVal = 0.0;
      int doneCount = 0;
      if (goal.subTasks.isNotEmpty) {
        doneCount = goal.subTasks.where((t) => t.isDone).length;
        progressVal = doneCount / goal.subTasks.length;
      } else {
        progressVal = goal.isDone ? 1.0 : 0.0;
      }

      final addCtrl = TextEditingController();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(gradient: accentGradient),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Title + Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.title,
                                style: AppFonts.text(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: text1,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (goal.deadline.isNotEmpty && goal.deadline != 'Ongoing') ...[
                                const SizedBox(height: 3),
                                Text(
                                  goal.deadline,
                                  style: AppFonts.text(
                                    fontSize: 11.5,
                                    color: text3,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 9),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pillBorder, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: pillText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                pillLabel,
                                style: AppFonts.compact(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: pillText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Progress Section (for Right Section or when subtasks exist)
                    if (!isLeft || goal.subTasks.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: AppFonts.text(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: text3,
                            ),
                          ),
                          Text(
                            '${(progressVal * 100).round()}%',
                            style: AppFonts.compact(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: pillText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          height: 5,
                          width: double.infinity,
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progressVal,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: progressGradient,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Move button between Left <-> Right
                        GestureDetector(
                          onTap: () {
                            _moveGoalSection(goal, isLeft ? 'right' : 'left');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                              border: Border.all(color: cardBorder, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLeft ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                                  size: 13,
                                  color: isLeft ? emeraldColor : azureColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isLeft ? 'Move to I Can Do ⚡' : 'Move to Let Go 🍃',
                                  style: AppFonts.text(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isLeft ? emeraldColor : azureColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            // Check button (Complete)
                            if (!isLeft) ...[
                              GestureDetector(
                                onTap: () => _toggleGoalCompletion(goal),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: isCompleted
                                        ? emeraldColor.withValues(alpha: 0.12)
                                        : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                                    border: Border.all(
                                      color: isCompleted ? emeraldColor.withValues(alpha: 0.3) : cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: isCompleted ? emeraldColor : text3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Checklist button (Subtasks)
                              GestureDetector(
                                onTap: () {
                                  HapticService.selection();
                                  setState(() {
                                    if (expanded) {
                                      _expandedGoalIds.remove(goal.id);
                                    } else {
                                      _expandedGoalIds.add(goal.id);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: expanded
                                        ? azureColor.withValues(alpha: 0.12)
                                        : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                                    border: Border.all(
                                      color: expanded ? azureColor.withValues(alpha: 0.3) : cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.list_alt_rounded,
                                    size: 16,
                                    color: expanded ? azureColor : text3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Delete button
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    backgroundColor: cardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: cardBorder, width: 0.5),
                                    ),
                                    title: Text(
                                      isLeft ? 'Delete Thought' : 'Delete Goal',
                                      style: AppFonts.display(
                                        fontWeight: FontWeight.w800,
                                        color: text1,
                                      ),
                                    ),
                                    content: Text(
                                      'Are you sure you want to remove this item?',
                                      style: AppFonts.text(color: text3),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: Text(
                                          'Cancel',
                                          style: AppFonts.text(
                                            fontWeight: FontWeight.w600,
                                            color: text3,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dialogContext);
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) _deleteGoal(goal);
                                          });
                                        },
                                        child: Text(
                                          'Delete',
                                          style: AppFonts.text(
                                            fontWeight: FontWeight.w600,
                                            color: redColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: redColor.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: redColor.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: redColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Subtasks checklist list (when expanded)
                    if (expanded) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 14),
                      if (goal.subTasks.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: goal.subTasks.length,
                          itemBuilder: (context, idx) {
                            final sub = goal.subTasks[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleSubTask(goal, sub),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: sub.isDone ? emeraldColor : Colors.transparent,
                                        border: Border.all(
                                          color: sub.isDone ? emeraldColor : text3.withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: sub.isDone
                                          ? const Icon(Icons.check, color: Colors.white, size: 12)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      sub.title,
                                      style: AppFonts.text(
                                        fontSize: 13.5,
                                        color: sub.isDone ? text3 : text1,
                                        decoration: sub.isDone ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _deleteSubTask(goal, sub),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: text3.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorder, width: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: addCtrl,
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _addSubTask(goal, val.trim());
                              addCtrl.clear();
                            }
                          },
                          style: AppFonts.text(fontSize: 12.5, color: text1),
                          decoration: InputDecoration(
                            hintText: '+ Add a step...',
                            hintStyle: AppFonts.text(fontSize: 12.5, color: text3),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Quick add button helper
    Widget buildQuickAddCard() {
      final isLeft = _selectedSection == 'left';
      return GestureDetector(
        onTap: () => _showAddGoalSheet(defaultSection: _selectedSection),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            color: (isLeft ? azureColor : emeraldColor).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isLeft ? azureColor : emeraldColor).withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLeft ? Icons.spa_outlined : Icons.add_circle_outline_rounded,
                size: 18,
                color: isLeft ? azureColor : emeraldColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isLeft ? '+ Dump to Left Section 🍃' : '+ Add Actionable Goal ⚡',
                  style: AppFonts.display(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isLeft ? azureColor : emeraldColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MIND DUMP & VISION',
                          style: AppFonts.text(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: emeraldColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Goals',
                          style: AppFonts.display(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Left: Out of control • Right: In my control',
                          style: AppFonts.text(
                            fontSize: 13,
                            color: text3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onScreenshot != null)
                    GestureDetector(
                      onTap: widget.onScreenshot,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: emeraldColor,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Share',
                              style: AppFonts.compact(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Dual-Section Switcher (Left vs Right)
              buildSectionSwitcher(),
              const SizedBox(height: 14),

              // Contextual Banner Explaining Section
              buildSectionBanner(),
              const SizedBox(height: 16),

              // Section Content
              if (currentSectionGoals.isEmpty)
                buildEmptyState()
              else ...[
                ...activeGoals.map((goal) => buildGoalCard(goal)),
                if (completedGoals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Completed',
                    style: AppFonts.text(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: text3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...completedGoals.map((goal) => buildGoalCard(goal)),
                ],
                const SizedBox(height: 16),
                buildQuickAddCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  DashedBorderPainter({required this.color, this.radius = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    ));

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final pm = path.computeMetrics().first;
    final dashPath = Path();
    double distance = 0.0;
    while (distance < pm.length) {
      dashPath.addPath(
        pm.extractPath(distance, distance + dashWidth),
        Offset.zero,
      );
      distance += dashWidth + dashSpace;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
