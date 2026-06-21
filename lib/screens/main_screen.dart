import 'dart:async';

import 'package:flutter/material.dart';

import '../core/colors.dart';
import '../widgets/custom_card.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  late final Timer _timer;
  DateTime _now = DateTime.now();
  final List<bool> _tasks = List<bool>.filled(_schedule.length, false);
  final Set<String> _prayersDone = {};
  final Map<String, bool> _habits = {for (final habit in _habitsData) habit.title: false};
  int _nikotex = 0;
  DateTime _smokeStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final nextNow = DateTime.now();
      if (nextNow.day != _now.day ||
          nextNow.month != _now.month ||
          nextNow.year != _now.year) {
        setState(() => _now = nextNow);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            _TodayTab(
              now: _now,
              tasks: _tasks,
              prayersDone: _prayersDone,
              smokeDays: _smokeDays,
              onTaskToggle: (index) => setState(() => _tasks[index] = !_tasks[index]),
              onPrayerToggle: _togglePrayer,
            ),
            const _GoalsTab(),
            _HabitsTab(
              habits: _habits,
              nikotex: _nikotex,
              smokeDays: _smokeDays,
              onHabitToggle: (title) => setState(() => _habits[title] = !(_habits[title] ?? false)),
              onNikotexChange: (change) => setState(() => _nikotex = (_nikotex + change).clamp(0, 8)),
              onSmokeReset: () => setState(() => _smokeStart = DateTime.now()),
            ),
            const _WorkoutTab(),
            const _IncomeTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        backgroundColor: kBg.withValues(alpha: 0.97),
        indicatorColor: tint(kGold, 0.18),
        height: 76,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.track_changes_outlined), selectedIcon: Icon(Icons.track_changes), label: 'Goals'),
          NavigationDestination(icon: Icon(Icons.local_fire_department_outlined), selectedIcon: Icon(Icons.local_fire_department), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Workout'),
          NavigationDestination(icon: Icon(Icons.currency_rupee_outlined), selectedIcon: Icon(Icons.currency_rupee), label: 'Income'),
        ],
      ),
    );
  }

  int get _smokeDays => DateTime.now().difference(_smokeStart).inDays;

  void _togglePrayer(String prayer) {
    setState(() {
      if (_prayersDone.contains(prayer)) {
        _prayersDone.remove(prayer);
      } else {
        _prayersDone.add(prayer);
      }
    });
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.now,
    required this.tasks,
    required this.prayersDone,
    required this.smokeDays,
    required this.onTaskToggle,
    required this.onPrayerToggle,
  });

  final DateTime now;
  final List<bool> tasks;
  final Set<String> prayersDone;
  final int smokeDays;
  final ValueChanged<int> onTaskToggle;
  final ValueChanged<String> onPrayerToggle;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((task) => task).length;
    final percent = (done / tasks.length * 100).round();
    final daysLeft = DateTime(2027, 1, 1).difference(now).inDays;

    return _TabPage(
      children: [
        const _Header(title: 'Rayees', subtitle: 'Industrial Automation Engineer - Life Plan 2027'),
        AppCard(
          borderColor: kBorderStrong,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_time(now), style: const TextStyle(color: kGold, fontSize: 32, fontWeight: FontWeight.w800)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_date(now), style: const TextStyle(color: kT1, fontWeight: FontWeight.w800)),
                  Text(_weekday(now), style: const TextStyle(color: kT3, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          borderColor: tint(kGold, 0.28),
          child: Column(
            children: [
              Text('$daysLeft', style: const TextStyle(color: kGold, fontSize: 56, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(height: 5),
              const Text('DAYS REMAINING', style: TextStyle(color: kT3, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text('Deadline - January 1, 2027', style: TextStyle(color: kT3, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.42,
          children: [
            _StatCard('Tasks today', '$done/${tasks.length}', 'completed'),
            _StatCard('Prayers done', '${prayersDone.length}/7', 'today', valueColor: kGold),
            _StatCard('Smoke-free', '$smokeDays', 'days', valueColor: kGreen),
            const _StatCard('Target', 'Rs 10K', 'per day', valueColor: kGold),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Today\'s progress', style: TextStyle(color: kT1, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('$percent%', style: const TextStyle(color: kTeal, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / tasks.length,
                  minHeight: 7,
                  color: kTeal,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ProgressMeta('Done', '$done'),
                  _ProgressMeta('Left', '${tasks.length - done}'),
                  const _ProgressMeta('Streak', '0d'),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel('Today\'s prayers'),
        SizedBox(
          height: 92,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            cacheExtent: 1000,
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            itemCount: _prayers.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prayer = _prayers[index];
              final selected = prayersDone.contains(prayer.title);
              return RepaintBoundary(
                child: _PrayerChip(
                  prayer: prayer,
                  selected: selected,
                  onTap: () => onPrayerToggle(prayer.title),
                ),
              );
            },
          ),
        ),
        const SectionLabel('Daily schedule'),
        ...List.generate(_schedule.length, (index) {
          final item = _schedule[index];
          return RepaintBoundary(
            child: _ScheduleTile(
              item: item,
              done: tasks[index],
              onChanged: () => onTaskToggle(index),
            ),
          );
        }),
      ],
    );
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context) {
    return _TabPage(
      children: const [
        _Header(title: 'Goals 2027', subtitle: 'Faith, body, career, money, and discipline'),
        _GoalCard(icon: Icons.mosque, color: kGold, title: 'Faith', subtitle: 'All 7 prayers daily', lines: ['Tahajjud and Fajr become identity', 'Read Quran every day', 'Keep phone away from prayer time']),
        _GoalCard(icon: Icons.engineering, color: kBlue, title: 'Career', subtitle: 'Automation engineer growth', lines: ['TIA Portal 2 hours every morning', 'Build Siemens PLC/HMI portfolio', 'Apply for high-value automation work']),
        _GoalCard(icon: Icons.fitness_center, color: kGreen, title: 'Body', subtitle: 'Strong chest, abs, legs, hands', lines: ['Workout 4 days every week', 'No fast food at night', 'Stop smoking completely']),
        _GoalCard(icon: Icons.currency_rupee, color: kGold, title: 'Income', subtitle: 'Rs 10K/day target', lines: ['Start with PLC/HMI projects', 'Freelance and direct clients', 'Reach Rs 3,00,000/month']),
      ],
    );
  }
}

class _HabitsTab extends StatelessWidget {
  const _HabitsTab({
    required this.habits,
    required this.nikotex,
    required this.smokeDays,
    required this.onHabitToggle,
    required this.onNikotexChange,
    required this.onSmokeReset,
  });

  final Map<String, bool> habits;
  final int nikotex;
  final int smokeDays;
  final ValueChanged<String> onHabitToggle;
  final ValueChanged<int> onNikotexChange;
  final VoidCallback onSmokeReset;

  @override
  Widget build(BuildContext context) {
    return _TabPage(
      children: [
        const _Header(title: 'Habits', subtitle: 'Small wins, every day'),
        AppCard(
          borderColor: tint(kRed, 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Smoking control', style: TextStyle(color: kT1, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Track Nikotex and protect the smoke-free streak.', style: TextStyle(color: kT2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nikotex today', style: TextStyle(color: kT2, fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      _RoundButton(icon: Icons.remove, onTap: () => onNikotexChange(-1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('$nikotex', style: TextStyle(color: nikotex > 4 ? kRed : kT1, fontSize: 28, fontWeight: FontWeight.w800)),
                      ),
                      _RoundButton(icon: Icons.add, onTap: () => onNikotexChange(1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Smoke-free days', style: TextStyle(color: kT2, fontWeight: FontWeight.w700)),
                  Text('$smokeDays', style: const TextStyle(color: kRed, fontSize: 28, fontWeight: FontWeight.w800)),
                ],
              ),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onSmokeReset, child: const Text('Reset'))),
            ],
          ),
        ),
        const SectionLabel('Habit checklist'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.05,
          children: [
            for (final habit in _habitsData)
              RepaintBoundary(
                child: _HabitCard(
                  habit: habit,
                  done: habits[habit.title] ?? false,
                  onTap: () => onHabitToggle(habit.title),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WorkoutTab extends StatelessWidget {
  const _WorkoutTab();

  @override
  Widget build(BuildContext context) {
    return _TabPage(
      children: const [
        _Header(title: 'Workout Plan', subtitle: 'Chest, six pack, strong legs, big hands'),
        _InfoBox(color: kGreen, text: 'Six pack truth: abs exist already. Diet reveals them. Stop smoking, train consistently, and keep the plan simple.'),
        SectionLabel('4-day split'),
        _ExpandablePlan(icon: Icons.fitness_center, color: kBlue, title: 'Day 1 - Chest & Triceps', subtitle: 'Mon - Thu', lines: ['Wide grip push-ups - 4 x 15-20', 'Decline push-ups - 3 x 12', 'Diamond push-ups - 3 x 10-15', 'Chair dips - 4 x 12-15']),
        _ExpandablePlan(icon: Icons.directions_run, color: kGreen, title: 'Day 2 - Legs & Abs', subtitle: 'Tue - Fri', lines: ['Bodyweight squats - 4 x 20-25', 'Jump squats - 3 x 15', 'Lunges - 3 x 12 each leg', 'Plank - 4 x 45-60 sec', 'Leg raises - 3 x 15']),
        _ExpandablePlan(icon: Icons.accessibility_new, color: kGold, title: 'Day 3 - Back & Biceps', subtitle: 'Wed - Sat', lines: ['Pull-ups or chin-ups - 4 x max', 'Inverted rows - 4 x 12', 'Towel bicep curls - 3 x 15 each arm']),
        _ExpandablePlan(icon: Icons.local_fire_department, color: kRed, title: 'Day 4 - HIIT Full Body', subtitle: 'Sun - fat burn', lines: ['Burpees - 4 x 10', 'Mountain climbers - 4 x 30 sec', 'Russian twists - 3 x 20', 'High knees - 4 x 30 sec']),
        _ExpandablePlan(icon: Icons.back_hand, color: kPurple, title: 'Hands & Forearms', subtitle: 'Every day - 10 minutes', lines: ['Towel wring - 3 x 30 sec', 'Finger push-ups - 3 x 8-10', 'Bucket carry - 3 x 30 sec each hand']),
      ],
    );
  }
}

class _IncomeTab extends StatelessWidget {
  const _IncomeTab();

  @override
  Widget build(BuildContext context) {
    return _TabPage(
      children: const [
        _Header(title: 'Rs 10K/day Plan', subtitle: 'Industrial automation career to Rs 3 lakhs/month'),
        AppCard(
          borderColor: Color(0x47F4C96E),
          child: Column(
            children: [
              Text('Rs 10,000', style: TextStyle(color: kGold, fontSize: 40, fontWeight: FontWeight.w800)),
              Text('per day - Rs 3,00,000 per month', style: TextStyle(color: kT3, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SectionLabel('Monthly milestones'),
        _Milestone(color: kBlue, period: 'Month 1-2', amount: 'Rs 30,000/mo', text: 'First PLC projects. Build portfolio. Show employers TIA Portal skills.'),
        _Milestone(color: kPurple, period: 'Month 3-4', amount: 'Rs 75,000/mo', text: 'Siemens specialist. Freelance HMI projects. First real automation role.'),
        _Milestone(color: kTeal, period: 'Month 5-6', amount: 'Rs 1,50,000/mo', text: 'Senior automation engineer. Multiple high-value projects.'),
        _Milestone(color: kGold, period: 'Month 7-8', amount: 'Rs 3,00,000/mo', text: 'Automation expert. Siemens, SCADA, drives. Goal achieved.'),
        SectionLabel('Non-negotiable rules'),
        _Rule(number: '1', text: 'HMD phone only after 10 PM. Smartphone in another room.'),
        _Rule(number: '2', text: 'All 7 prayers. Tahajjud, Fajr, Dhuha, Dhuhr, Asr, Maghrib, Isha.'),
        _Rule(number: '3', text: 'TIA Portal 2 hours every morning. Career compound interest.'),
      ],
    );
  }
}

class _TabPage extends StatelessWidget {
  const _TabPage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            cacheExtent: 1000,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 20),
          children: children,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title == 'Rayees') const Center(child: Text('BISMILLAH', style: TextStyle(color: kGold, letterSpacing: 3, fontWeight: FontWeight.w800))),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: kT3, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.sub, {this.valueColor = kT1});

  final String label;
  final String value;
  final String sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: kT4, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(color: kT3, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProgressMeta extends StatelessWidget {
  const _ProgressMeta(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text.rich(
        TextSpan(text: '$label: ', children: [TextSpan(text: value, style: const TextStyle(color: kT1, fontWeight: FontWeight.w800))]),
        style: const TextStyle(color: kT2, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PrayerChip extends StatelessWidget {
  const _PrayerChip({required this.prayer, required this.selected, required this.onTap});

  final _Prayer prayer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tint(prayer.color),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: selected ? kTeal : kBorder),
              ),
              child: Icon(prayer.icon, color: selected ? kTeal : prayer.color),
            ),
            const SizedBox(height: 5),
            Text(prayer.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? kTeal : kT3, fontSize: 10, fontWeight: FontWeight.w800)),
            Text(prayer.time, style: const TextStyle(color: kT4, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({required this.item, required this.done, required this.onChanged});

  final _ScheduleItem item;
  final bool done;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        borderColor: done ? tint(kTeal, 0.28) : (item.color == kGold ? tint(kGold, 0.18) : kBorder),
        child: Row(
          children: [
            SizedBox(width: 54, child: Text(item.time, style: const TextStyle(color: kT4, fontSize: 11, fontWeight: FontWeight.w800))),
            AccentIcon(item.icon, color: item.color),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(color: kT1, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(item.tag, style: TextStyle(color: item.color, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Checkbox(value: done, onChanged: (_) => onChanged(), activeColor: kTeal),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.lines});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AccentIcon(icon, color: color),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: kT1, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(subtitle, style: const TextStyle(color: kT2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final line in lines) _Bullet(line, color: color),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.done, required this.onTap});

  final _Habit habit;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(habit.icon, color: habit.color),
              const SizedBox(width: 8),
              Expanded(child: Text(habit.title, style: const TextStyle(color: kT1, fontWeight: FontWeight.w800))),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: done ? habit.color : Colors.white.withValues(alpha: 0.07), foregroundColor: done ? kBg : kT2),
              onPressed: onTap,
              child: Text(done ? 'Done' : 'Mark done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(onPressed: onTap, icon: Icon(icon), color: kT1);
  }
}

class _ExpandablePlan extends StatefulWidget {
  const _ExpandablePlan({required this.icon, required this.color, required this.title, required this.subtitle, required this.lines});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> lines;

  @override
  State<_ExpandablePlan> createState() => _ExpandablePlanState();
}

class _ExpandablePlanState extends State<_ExpandablePlan> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        onTap: () => setState(() => open = !open),
        child: Column(
          children: [
            Row(
              children: [
                AccentIcon(widget.icon, color: widget.color),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(color: kT1, fontWeight: FontWeight.w800)),
                      Text(widget.subtitle, style: TextStyle(color: widget.color, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Icon(open ? Icons.expand_less : Icons.chevron_right, color: kT3),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 12),
              for (final line in widget.lines) _Bullet(line, color: widget.color),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: tint(color, 0.07),
      borderColor: tint(color, 0.18),
      child: Text(text, style: const TextStyle(color: kT2, fontWeight: FontWeight.w700, height: 1.5)),
    );
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.color, required this.period, required this.amount, required this.text});

  final Color color;
  final String period;
  final String amount;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(period.toUpperCase(), style: const TextStyle(color: kT3, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  Text(amount, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(text, style: const TextStyle(color: kT2, fontWeight: FontWeight.w600, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number, style: const TextStyle(color: kGold, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: kT2, fontWeight: FontWeight.w700, height: 1.5))),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: kT2, fontWeight: FontWeight.w600, height: 1.5))),
        ],
      ),
    );
  }
}

String _time(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _date(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _weekday(DateTime date) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return days[date.weekday - 1];
}

class _ScheduleItem {
  const _ScheduleItem(this.time, this.title, this.tag, this.icon, this.color);

  final String time;
  final String title;
  final String tag;
  final IconData icon;
  final Color color;
}

class _Prayer {
  const _Prayer(this.title, this.time, this.icon, this.color);

  final String title;
  final String time;
  final IconData icon;
  final Color color;
}

class _Habit {
  const _Habit(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;
}

const _schedule = [
  _ScheduleItem('3:30', 'Tahajjud', 'Prayer and dua', Icons.nights_stay, kPurple),
  _ScheduleItem('5:00', 'Fajr prayer', 'Start clean', Icons.dark_mode, kTeal),
  _ScheduleItem('6:00', 'Morning walk', 'Body and mind', Icons.directions_walk, kGreen),
  _ScheduleItem('7:00', 'TIA Portal study', 'Career compound interest', Icons.precision_manufacturing, kBlue),
  _ScheduleItem('9:30', 'Work / projects', 'Automation skill building', Icons.engineering, kAmber),
  _ScheduleItem('13:15', 'Dhuhr prayer', 'Reset focus', Icons.wb_sunny, kGold),
  _ScheduleItem('16:30', 'Asr prayer', 'Discipline checkpoint', Icons.light_mode, kGold),
  _ScheduleItem('18:30', 'Workout', 'Strength and fat burn', Icons.fitness_center, kGreen),
  _ScheduleItem('19:00', 'Maghrib prayer', 'Evening reset', Icons.wb_twilight, kGold),
  _ScheduleItem('20:00', 'Dinner clean', 'No fast food at night', Icons.restaurant, kRed),
  _ScheduleItem('21:00', 'Isha prayer', 'Close the day well', Icons.mosque, kGold),
  _ScheduleItem('22:00', 'HMD phone only', 'Smartphone away', Icons.phone_android, kRed),
  _ScheduleItem('22:30', 'Quran reading', 'Daily connection', Icons.menu_book, kTeal),
  _ScheduleItem('23:00', 'Sleep', 'Protect tomorrow', Icons.bedtime, kPurple),
];

const _prayers = [
  _Prayer('Tahajjud', '3:30 AM', Icons.nights_stay, kPurple),
  _Prayer('Fajr', '5:00 AM', Icons.dark_mode, kTeal),
  _Prayer('Dhuha', '8:00 AM', Icons.wb_sunny, kAmber),
  _Prayer('Dhuhr', '1:15 PM', Icons.light_mode, kGold),
  _Prayer('Asr', '4:30 PM', Icons.sunny, kBlue),
  _Prayer('Maghrib', '7:00 PM', Icons.wb_twilight, kRed),
  _Prayer('Isha', '9:00 PM', Icons.mosque, kPurple),
];

const _habitsData = [
  _Habit('Tahajjud', Icons.nights_stay, kPurple),
  _Habit('Fajr prayer', Icons.dark_mode, kTeal),
  _Habit('Quran reading', Icons.menu_book, kTeal),
  _Habit('Morning walk', Icons.directions_walk, kGreen),
  _Habit('Workout done', Icons.fitness_center, kGreen),
  _Habit('2.5L water', Icons.water_drop, kBlue),
  _Habit('Shower AM+PM', Icons.shower, kPink),
  _Habit('HMD only 10PM', Icons.phone_android, kRed),
];
