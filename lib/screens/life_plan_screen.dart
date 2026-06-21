import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

class LifeGoal {
  String id;
  String title;
  String deadline;
  double progress;
  Color color;
  bool isDone;

  LifeGoal({
    required this.id,
    required this.title,
    required this.deadline,
    required this.progress,
    required this.color,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'deadline': deadline,
    'progress': progress,
    'color': color.toARGB32(),
    'isDone': isDone,
  };

  factory LifeGoal.fromJson(Map<String, dynamic> json) => LifeGoal(
    id: json['id'] as String,
    title: json['title'] as String,
    deadline: json['deadline'] as String,
    progress: (json['progress'] as num).toDouble(),
    color: Color(json['color'] as int),
    isDone: json['isDone'] as bool? ?? false,
  );
}

class LifePlanScreen extends StatefulWidget {
  const LifePlanScreen({super.key, required this.theme});
  final ThemeColors theme;

  @override
  State<LifePlanScreen> createState() => _LifePlanScreenState();
}

class _LifePlanScreenState extends State<LifePlanScreen> {
  List<LifeGoal> _goals = [];
  bool _isLoading = true;

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

  Future<void> _incrementProgress(LifeGoal goal) async {
    setState(() {
      double p = goal.progress + 0.05;
      if (p > 1.0) p = 1.0;
      goal.progress = p;
    });
    _saveGoals();
  }

  void _deleteGoal(LifeGoal goal) {
    setState(() {
      _goals.remove(goal);
    });
    _saveGoals();
  }

  void _showAddGoalSheet() {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    double progressVal = 0.0;
    Color selectedColor = kBlue;

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
                  Text(
                    'Add New Goal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.theme.text1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: widget.theme.text1),
                    decoration: InputDecoration(
                      labelText: 'Goal Title',
                      labelStyle: TextStyle(color: widget.theme.text3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kGold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dateCtrl,
                    style: TextStyle(color: widget.theme.text1),
                    decoration: InputDecoration(
                      labelText: 'Target Date (e.g. Dec 2025)',
                      labelStyle: TextStyle(color: widget.theme.text3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kGold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Progress: ${(progressVal * 100).round()}%',
                    style: TextStyle(color: widget.theme.text3),
                  ),
                  Slider(
                    value: progressVal,
                    onChanged: (val) {
                      if (mounted) {
                        setSheetState(() => progressVal = val);
                      }
                    },
                    activeColor: selectedColor,
                    inactiveColor: widget.theme.border,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:
                        [
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final deadline = dateCtrl.text.trim().isEmpty
                            ? 'Ongoing'
                            : dateCtrl.text.trim();
                        if (title.isEmpty) return;
                        final goal = LifeGoal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          deadline: deadline,
                          progress: progressVal,
                          color: selectedColor,
                        );

                        FocusScope.of(sheetContext).unfocus();
                        titleCtrl.clear();
                        dateCtrl.clear();
                        Navigator.pop(sheetContext);

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _goals.add(goal);
                            });
                            _saveGoals();
                          }
                        });
                      },
                      child: const Text(
                        'Add Goal',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _addFocusButton(ThemeColors theme) {
    return GestureDetector(
      onTap: _showAddGoalSheet,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 22),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.text4.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: Text(
          '+ Add Focus Area',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: theme.text2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(LifeGoal goal, ThemeColors theme) {
    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) => _deleteGoal(goal),
      child: GestureDetector(
        onTap: () => _incrementProgress(goal),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: goal.isDone ? 0.6 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: goal.isDone ? theme.text4 : theme.text1,
                          decoration: goal.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      goal.deadline,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.text3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        goal.isDone
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: goal.isDone ? kGreen : theme.text4,
                      ),
                      onPressed: () {
                        setState(() {
                          goal.isDone = !goal.isDone;
                        });
                        _saveGoals();
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline, color: kRed),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: theme.card,
                            title: Text(
                              'Delete Goal',
                              style: TextStyle(color: theme.text1),
                            ),
                            content: Text(
                              'Are you sure you want to delete this goal?',
                              style: TextStyle(color: theme.text3),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: theme.text3),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) _deleteGoal(goal);
                                  });
                                },
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: kRed),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 8,
                    backgroundColor: theme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final daysRemaining = DateTime(2027, 1, 1).difference(DateTime.now()).inDays;
    final activeGoals = _goals.where((g) => !g.isDone).toList();
    final completedGoals = _goals.where((g) => g.isDone).toList();

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2026 Focus',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: theme.text3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: theme.text1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$daysRemaining days remaining',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.text3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                if (activeGoals.isEmpty && completedGoals.isEmpty) ...[
                  Text(
                    'No focus areas yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _addFocusButton(theme),
                ...activeGoals.map(
                  (goal) =>
                      RepaintBoundary(child: _buildGoalCard(goal, theme)),
                ),
                if (completedGoals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...completedGoals.map(
                    (goal) =>
                        RepaintBoundary(child: _buildGoalCard(goal, theme)),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton(
                onPressed: _showAddGoalSheet,
                backgroundColor: kGold,
                child: const Icon(Icons.add, color: Colors.black),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

