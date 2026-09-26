import 'dart:convert';
import 'package:flutter/material.dart';
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
  String _selectedSection = 'right'; // 'left' = Parked (Out of Control), 'right' = Action (In My Control)
  final Set<String> _expandedGoalIds = {};
  final Set<String> _swipedGoalIds = {};

  // Native iOS Theme Constants
  static const Color _kAccentTeal = Color(0xFF32D9B6);
  static const Color _kDestructiveRed = Color(0xFFFF453A);

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
      _swipedGoalIds.remove(goal.id);
    });
    _saveGoals();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          targetSection == 'left'
              ? 'Moved to Parked (Out of Control)'
              : 'Moved to Action (In My Control)',
          style: AppFonts.text(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: targetSection == 'left' ? const Color(0xFF2C2C2E) : _kAccentTeal,
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
      _swipedGoalIds.remove(goal.id);
      _expandedGoalIds.remove(goal.id);
    });
    _saveGoals();
  }

  void _showAddGoalSheet({String? defaultSection}) {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    String section = defaultSection ?? _selectedSection;
    final isDark = widget.theme.isDark;
    final sheetBg = isDark ? const Color(0xFF111214) : const Color(0xFFFFFFFF);
    final fieldBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final text1 = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF000000);
    final text2 = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, setSheetState) {
            final isLeft = section == 'left';
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grab handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x3DFFFFFF) : const Color(0x3D000000),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header
                  Text(
                    isLeft ? 'New Parked Thought' : 'New Action Goal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: text1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Segmented control inside modal
                  Container(
                    height: 36,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticService.selection();
                                  setSheetState(() => section = 'left');
                                },
                                child: Center(
                                  child: Text(
                                    'Parked (Let Go)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isLeft ? FontWeight.w600 : FontWeight.w500,
                                      color: isLeft ? text1 : text2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticService.selection();
                                  setSheetState(() => section = 'right');
                                },
                                child: Center(
                                  child: Text(
                                    'Action (In Control)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: !isLeft ? FontWeight.w600 : FontWeight.w500,
                                      color: !isLeft ? text1 : text2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title TextField
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: TextStyle(color: text1, fontSize: 16, fontWeight: FontWeight.w400),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      hintText: isLeft
                          ? 'e.g. Market trend, external outcome, worry...'
                          : 'e.g. Master Flutter, ship mobile feature...',
                      hintStyle: TextStyle(color: text2, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Optional note / target date
                  TextField(
                    controller: dateCtrl,
                    style: TextStyle(color: text1, fontSize: 15, fontWeight: FontWeight.w400),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      hintText: isLeft ? 'Context note (optional)' : 'Target deadline (e.g. Dec 2026)',
                      hintStyle: TextStyle(color: text2, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit CTA
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccentTeal,
                        foregroundColor: Colors.black,
                        elevation: 0,
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
                          progress: 0.0,
                          color: _kAccentTeal,
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
                        isLeft ? 'Add to Parked' : 'Add to Action',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteGoal(LifeGoal goal) {
    final isDark = widget.theme.isDark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final text1 = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF000000);
    final text2 = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          goal.section == 'left' ? 'Delete Parked Item' : 'Delete Goal',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: text1,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${goal.title}"?',
          style: TextStyle(color: text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: text2, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _deleteGoal(goal);
              });
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: _kDestructiveRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = widget.theme.isDark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final surfaceColor = isDark ? const Color(0xFF111214) : const Color(0xFFFFFFFF);
    final elevatedColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA);
    final hairlineColor = isDark ? const Color(0x17FFFFFF) : const Color(0x1F000000);

    final text1 = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF000000);
    final text2 = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final text3 = isDark ? const Color(0xFF5A5A5E) : const Color(0xFF8E8E93);

    final leftGoals = _goals.where((g) => g.section == 'left').toList();
    final rightGoals = _goals.where((g) => g.section != 'left').toList();

    final currentSectionGoals = _selectedSection == 'left' ? leftGoals : rightGoals;
    final activeGoals = currentSectionGoals.where((g) => !g.isDone).toList();
    final completedGoals = currentSectionGoals.where((g) => g.isDone).toList();

    // 1. Native iOS Segmented Control (Sliding gray thumb behind active label)
    Widget buildSegmentedControl() {
      final isLeft = _selectedSection == 'left';
      return Container(
        height: 38,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: elevatedColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticService.selection();
                      setState(() => _selectedSection = 'left');
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Parked',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isLeft ? FontWeight.w600 : FontWeight.w500,
                              color: isLeft ? text1 : text2,
                            ),
                          ),
                          if (leftGoals.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              '${leftGoals.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isLeft ? text2 : text3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticService.selection();
                      setState(() => _selectedSection = 'right');
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Action',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: !isLeft ? FontWeight.w600 : FontWeight.w500,
                              color: !isLeft ? text1 : text2,
                            ),
                          ),
                          if (rightGoals.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              '${rightGoals.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: !isLeft ? text2 : text3,
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
          ],
        ),
      );
    }

    // 2. Section Explanation (Plain text block with small monochrome line icon above hairline divider)
    Widget buildSectionExplanation() {
      final isLeft = _selectedSection == 'left';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isLeft ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded,
                size: 16,
                color: text2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLeft ? 'OUT OF MY CONTROL — LET GO' : 'IN MY CONTROL — ACTIONABLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.08 * 11,
                        color: text2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isLeft
                          ? 'Dump ideas, worries, and uncontrollable factors here. Zero stress — no need to manage.'
                          : 'Goals and steps within your power. Focus your daily execution and energy here.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 0.5, thickness: 0.5, color: hairlineColor),
        ],
      );
    }

    // 3. Empty State (Clean dark circle, title + description, full-width single accent CTA button)
    Widget buildEmptyState() {
      final isLeft = _selectedSection == 'left';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: elevatedColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLeft ? Icons.pause_rounded : Icons.flag_outlined,
                size: 28,
                color: text2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLeft ? 'Parked is clear' : 'No action goals yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLeft
                  ? 'Have worries, external factors, or uncontrollable thoughts? Dump them here to free your mind.'
                  : 'Add goals and milestones that you can take action on yourself.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: text2,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccentTeal,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showAddGoalSheet(defaultSection: _selectedSection),
                child: Text(
                  isLeft ? 'Add to Parked' : 'Add Action Goal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Goal Row inside Single Grouped Container
    Widget buildGoalRow(LifeGoal goal, {required bool isFirst, required bool isLast}) {
      final isLeft = goal.section == 'left';
      final isDone = goal.isDone;
      final expanded = _expandedGoalIds.contains(goal.id);
      final swiped = _swipedGoalIds.contains(goal.id);

      double progressVal = 0.0;
      if (goal.subTasks.isNotEmpty) {
        final doneCount = goal.subTasks.where((t) => t.isDone).length;
        progressVal = doneCount / goal.subTasks.length;
      } else {
        progressVal = isDone ? 1.0 : 0.0;
      }
      final percentInt = (progressVal * 100).round();
      final addSubCtrl = TextEditingController();

      return Column(
        children: [
          Dismissible(
            key: ValueKey('goal_${goal.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              setState(() {
                if (_swipedGoalIds.contains(goal.id)) {
                  _swipedGoalIds.remove(goal.id);
                } else {
                  _swipedGoalIds.add(goal.id);
                }
              });
              return false; // Reveal actions without auto-dismissing
            },
            background: Container(
              color: elevatedColor,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _moveGoalSection(goal, isLeft ? 'right' : 'left'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isLeft ? 'To Action' : 'To Parked',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmDeleteGoal(goal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kDestructiveRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            child: InkWell(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Leading: 36px Circular Progress Ring
                    GestureDetector(
                      onTap: () => _toggleGoalCompletion(goal),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: isLeft ? 1.0 : progressVal,
                              strokeWidth: 3,
                              backgroundColor: isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isLeft
                                    ? text3
                                    : (isDone ? _kAccentTeal : _kAccentTeal.withValues(alpha: 0.8)),
                              ),
                            ),
                            if (isDone)
                              const Icon(Icons.check_rounded, size: 16, color: _kAccentTeal)
                            else if (isLeft)
                              Icon(Icons.pause_rounded, size: 14, color: text3)
                            else
                              Text(
                                '$percentInt%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: text1,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Middle: Title + Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDone ? text3 : text1,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            goal.deadline.isNotEmpty && goal.deadline != 'Ongoing'
                                ? '${isLeft ? "Parked" : "Actionable"} · ${goal.deadline}'
                                : (isLeft ? 'Parked thought' : 'Actionable goal'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: text2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons or revealed state
                    if (swiped) ...[
                      GestureDetector(
                        onTap: () => _moveGoalSection(goal, isLeft ? 'right' : 'left'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: elevatedColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLeft ? 'Action' : 'Park',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _confirmDeleteGoal(goal),
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: _kDestructiveRed),
                      ),
                    ] else ...[
                      Icon(
                        expanded ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
                        size: 20,
                        color: text3,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Expanded checklist & actions
          if (expanded) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              color: isDark ? const Color(0xFF0D0E10) : const Color(0xFFF9F9FB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 0.5, thickness: 0.5, color: hairlineColor),
                  const SizedBox(height: 10),

                  // Subtasks
                  if (goal.subTasks.isNotEmpty)
                    ...goal.subTasks.map((sub) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleSubTask(goal, sub),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: sub.isDone ? _kAccentTeal : Colors.transparent,
                                  border: Border.all(
                                    color: sub.isDone ? _kAccentTeal : text3,
                                    width: 1.5,
                                  ),
                                ),
                                child: sub.isDone
                                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.black)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sub.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: sub.isDone ? text3 : text1,
                                  decoration: sub.isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _deleteSubTask(goal, sub),
                              child: Icon(Icons.close_rounded, size: 16, color: text3),
                            ),
                          ],
                        ),
                      );
                    }),

                  // Add step input
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: elevatedColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            controller: addSubCtrl,
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                _addSubTask(goal, val.trim());
                                addSubCtrl.clear();
                              }
                            },
                            style: TextStyle(fontSize: 13, color: text1),
                            decoration: InputDecoration(
                              hintText: '+ Add step or checklist item...',
                              hintStyle: TextStyle(fontSize: 13, color: text3),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Move button
                      GestureDetector(
                        onTap: () => _moveGoalSection(goal, isLeft ? 'right' : 'left'),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: elevatedColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isLeft ? 'Move to Action' : 'Move to Parked',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Delete button
                      GestureDetector(
                        onTap: () => _confirmDeleteGoal(goal),
                        child: Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: _kDestructiveRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.delete_outline_rounded, size: 16, color: _kDestructiveRed),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (!isLast) Divider(height: 0.5, thickness: 0.5, color: hairlineColor),
        ],
      );
    }

    // 5. Grouped Container for Goal Rows
    Widget buildGroupedGoalList(List<LifeGoal> goals) {
      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hairlineColor, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(goals.length, (index) {
            return buildGoalRow(
              goals[index],
              isFirst: index == 0,
              isLast: index == goals.length - 1,
            );
          }),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large Title (iOS 34px, 800 weight, -0.02em letter spacing)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Goals',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.68,
                      color: text1,
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.onScreenshot != null) ...[
                        GestureDetector(
                          onTap: widget.onScreenshot,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: elevatedColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.share_outlined, size: 18, color: text1),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: () => _showAddGoalSheet(defaultSection: _selectedSection),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: _kAccentTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, size: 20, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segmented Control (Parked / Action)
              buildSegmentedControl(),
              const SizedBox(height: 16),

              // Plain Text Section Explanation + Hairline Divider
              buildSectionExplanation(),
              const SizedBox(height: 16),

              // Goals List or Empty State
              if (currentSectionGoals.isEmpty)
                buildEmptyState()
              else ...[
                if (activeGoals.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      _selectedSection == 'left' ? 'PARKED THOUGHTS' : 'ACTIVE GOALS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.08 * 11,
                        color: text2,
                      ),
                    ),
                  ),
                  buildGroupedGoalList(activeGoals),
                ],

                if (completedGoals.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'COMPLETED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.08 * 11,
                        color: text2,
                      ),
                    ),
                  ),
                  buildGroupedGoalList(completedGoals),
                ],

                const SizedBox(height: 20),

                // Secondary Add Row
                GestureDetector(
                  onTap: () => _showAddGoalSheet(defaultSection: _selectedSection),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hairlineColor, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: text2),
                        const SizedBox(width: 6),
                        Text(
                          _selectedSection == 'left' ? 'Add Parked Item' : 'Add Action Goal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
