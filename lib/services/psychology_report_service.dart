import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ============================================
// REPORT COLORS
// ============================================
class ReportColors {
  static const PdfColor darkBg = PdfColor(0.04, 0.04, 0.08); // #0B0B14
  static const PdfColor cardBg = PdfColor(0.09, 0.09, 0.13); // #161622
  static const PdfColor cardBg2 = PdfColor(0.07, 0.07, 0.10); // #11111A
  static const PdfColor teal = PdfColor(0.18, 0.83, 0.66); // #2DD4A8
  static const PdfColor gold = PdfColor(0.83, 0.66, 0.26); // #D4A843
  static const PdfColor text = PdfColor(0.92, 0.92, 0.96); // #EBEBF5
  static const PdfColor text2 = PdfColor(0.60, 0.60, 0.68); // #9898A8
  static const PdfColor muted = PdfColor(0.32, 0.32, 0.40); // #525266
  static const PdfColor border = PdfColor(0.16, 0.16, 0.24); // #29293D
}

// ============================================
// DATA MODELS
// ============================================
class DailyHabitData {
  final DateTime date;
  final int score;
  final int tasksDone;
  final int tasksTotal;
  final int prayersDone;
  final int prayersTotal;
  final Map<String, bool> taskBreakdown;
  final Map<String, bool> prayerBreakdown;
  final String? workoutName;

  DailyHabitData({
    required this.date,
    required this.score,
    required this.tasksDone,
    required this.tasksTotal,
    required this.prayersDone,
    required this.prayersTotal,
    required this.taskBreakdown,
    required this.prayerBreakdown,
    this.workoutName,
  });
}

class HabitReportData {
  final String userName;
  final DateTime startDate;
  final DateTime endDate;
  final List<DailyHabitData> days;

  HabitReportData({
    required this.userName,
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  int get totalDays => days.isEmpty ? 1 : days.length;
  int get appOpens => days.length;

  int get bestDayScore {
    if (days.isEmpty) return 0;
    return days.map((d) => d.score).reduce((a, b) => a > b ? a : b);
  }

  int get bestDayIndex {
    if (days.isEmpty) return 0;
    return days.indexWhere((d) => d.score == bestDayScore);
  }

  int get totalTasksDone =>
      days.isEmpty ? 0 : days.map((d) => d.tasksDone).reduce((a, b) => a + b);
  int get totalPrayersDone =>
      days.isEmpty ? 0 : days.map((d) => d.prayersDone).reduce((a, b) => a + b);

  double get week1Avg {
    if (days.length < 7) {
      return days.isEmpty
          ? 0
          : days.map((d) => d.score).reduce((a, b) => a + b) / days.length;
    }
    return days.sublist(0, 7).map((d) => d.score).reduce((a, b) => a + b) / 7.0;
  }

  double get week4Avg {
    if (days.length >= 28) {
      return days.sublist(days.length - 7).map((d) => d.score).reduce((a, b) => a + b) /
          7.0;
    }
    return week1Avg;
  }

  int get bestStreak {
    int current = 0;
    int best = 0;
    for (final day in days) {
      if (day.score > 0) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best > 0 ? best : (days.isNotEmpty ? 1 : 0);
  }

  Map<String, int> get taskTotals {
    final totals = <String, int>{};
    for (final day in days) {
      for (final entry in day.taskBreakdown.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + (entry.value ? 1 : 0);
      }
    }
    return totals;
  }

  Map<String, int> get prayerTotals {
    final totals = <String, int>{};
    for (final day in days) {
      for (final entry in day.prayerBreakdown.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + (entry.value ? 1 : 0);
      }
    }
    return totals;
  }

  String get strongestHabit {
    final all = {...taskTotals, ...prayerTotals};
    if (all.isEmpty) return 'Consistency';
    return all.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String get oneChangeInsight {
    final tasks = taskTotals;
    final zeroTasks = tasks.entries.where((e) => e.value == 0).toList();
    if (zeroTasks.isNotEmpty) {
      final target = zeroTasks.first.key;
      return 'If you complete "$target" just 3 times this month, your overall momentum will jump ~15%.';
    }
    final prayers = prayerTotals;
    final lowPrayer =
        prayers.entries.where((e) => e.value < totalDays * 0.4).firstOrNull;
    if (lowPrayer != null) {
      return 'If you pray ${lowPrayer.key} consistently just 4 more days, your prayer streak will double.';
    }
    return 'Your daily anchor habits are firing. Add one small progression next month for compounding gains.';
  }
}

// ============================================
// PSYCHOLOGY REPORT BUILDER
// ============================================
class PsychologyReportService {
  static Future<Uint8List> generatePdfBytes(HabitReportData data) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemi = await PdfGoogleFonts.interSemiBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (context) => pw.Container(
          color: ReportColors.darkBg,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Header
                _buildHeader(data, fontRegular, fontBold),
                pw.SizedBox(height: 10),
                pw.Divider(color: ReportColors.border, thickness: 0.8),
                pw.SizedBox(height: 12),

                // 2. Wins Section (Endowed Progress)
                _buildWinsSection(data, fontRegular, fontBold, fontSemi),
                pw.SizedBox(height: 14),

                // 3. Momentum Card (Peak-End Rule)
                _buildMomentumSection(data, fontRegular, fontBold, fontSemi),
                pw.SizedBox(height: 14),

                // 4. Daily Scores Bar Chart
                _buildScoreChart(data, fontRegular, fontBold),
                pw.SizedBox(height: 14),

                // 5. Habit Breakdown (Proximity & Competence)
                _buildHabitBreakdown(data, fontRegular, fontBold, fontSemi),
                pw.SizedBox(height: 12),

                // 6. Letter to Future Self + One Change
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _buildFutureSelfCard(data, fontRegular, fontBold, fontSemi),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: _buildOneChangeCard(data, fontRegular, fontBold, fontSemi),
                    ),
                  ],
                ),
                pw.Spacer(),

                // 7. Footer
                pw.Center(
                  child: pw.Text(
                    'Generated by Muttaqin · ${DateFormat('d MMM yyyy · hh:mm a').format(DateTime.now())}',
                    style: pw.TextStyle(
                      color: ReportColors.muted,
                      fontSize: 8,
                      font: fontRegular,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    HabitReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) {
    final dateRange =
        '${DateFormat('d MMM').format(data.startDate)} – ${DateFormat('d MMM yyyy').format(data.endDate)}';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MUTTAQIN',
              style: pw.TextStyle(
                color: ReportColors.gold,
                fontSize: 10,
                font: fontBold,
                letterSpacing: 2.0,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Month in Review',
              style: pw.TextStyle(
                color: ReportColors.text,
                fontSize: 22,
                font: fontBold,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              data.userName.isNotEmpty ? data.userName : 'Rayees',
              style: pw.TextStyle(
                color: ReportColors.text,
                fontSize: 13,
                font: fontBold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              dateRange,
              style: pw.TextStyle(
                color: ReportColors.text2,
                fontSize: 9.5,
                font: fontRegular,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildWinsSection(
    HabitReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontSemi,
  ) {
    final cards = <_WinItem>[];

    // Win 1: App attendance
    cards.add(_WinItem(
      title: 'App Opens',
      value: '${data.appOpens}/${data.totalDays}',
      subtitle: '100% attendance',
      color: ReportColors.teal,
    ));

    // Win 2 & 3: Top habits
    final allHabits = {...data.taskTotals, ...data.prayerTotals};
    final sorted = allHabits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top2 = sorted.take(2).toList();

    for (int i = 0; i < top2.length; i++) {
      final habit = top2[i];
      final isAnchor = i == 0;
      final remaining = data.totalDays - habit.value;
      cards.add(_WinItem(
        title: habit.key,
        value: '${habit.value}/${data.totalDays}',
        subtitle: remaining <= 3
            ? '$remaining to perfect'
            : (isAnchor ? 'Anchor habit' : 'Strong momentum'),
        color: isAnchor ? ReportColors.gold : ReportColors.teal,
      ));
    }

    // Win 4: Total actions completed
    final totalActions = data.totalTasksDone + data.totalPrayersDone;
    cards.add(_WinItem(
      title: 'Total Wins',
      value: '$totalActions',
      subtitle: 'Actions executed',
      color: ReportColors.teal,
    ));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'YOUR WINS · WHAT YOU PROVED THIS MONTH',
          style: pw.TextStyle(
            color: ReportColors.teal,
            fontSize: 9,
            font: fontBold,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: cards.map((item) {
            return pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: ReportColors.cardBg,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: item.color, width: 1.2),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      item.value,
                      style: pw.TextStyle(
                        color: item.color,
                        fontSize: 16,
                        font: fontBold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      item.title,
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: ReportColors.text,
                        fontSize: 8,
                        font: fontSemi,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      item.subtitle,
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: ReportColors.text2,
                        fontSize: 7,
                        font: fontRegular,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildMomentumSection(
    HabitReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontSemi,
  ) {
    final accelerating = data.week4Avg >= data.week1Avg;
    final statusText = accelerating ? 'Accelerating Momentum' : 'Steady Consistency';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: ReportColors.cardBg2,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: ReportColors.gold, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: const pw.BoxDecoration(
                  color: ReportColors.gold,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                statusText,
                style: pw.TextStyle(
                  color: ReportColors.gold,
                  fontSize: 10.5,
                  font: fontBold,
                ),
              ),
            ],
          ),
          pw.Text(
            'Week 1: ${data.week1Avg.round()}%  →  Week 4: ${data.week4Avg.round()}%',
            style: pw.TextStyle(
              color: ReportColors.text,
              fontSize: 9.5,
              font: fontSemi,
            ),
          ),
          pw.Text(
            'Best Streak: ${data.bestStreak} days',
            style: pw.TextStyle(
              color: ReportColors.teal,
              fontSize: 9.5,
              font: fontBold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScoreChart(
    HabitReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) {
    final count = data.days.length;
    final bestIdx = data.bestDayIndex;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: ReportColors.cardBg,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: ReportColors.border, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DAILY SCORE TREND · EVERY DAY YOU SHOWED UP',
                style: pw.TextStyle(
                  color: ReportColors.text2,
                  fontSize: 8.5,
                  font: fontBold,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Row(
                children: [
                  pw.Container(
                    width: 5,
                    height: 5,
                    decoration: const pw.BoxDecoration(
                      color: ReportColors.gold,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Text(
                    'Best Day (${data.bestDayScore}%)',
                    style: pw.TextStyle(
                      color: ReportColors.gold,
                      fontSize: 8,
                      font: fontBold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 65,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: List.generate(count, (i) {
                final score = data.days[i].score;
                final barHeight = (score.clamp(6, 100) / 100.0) * 55;
                final isBest = i == bestIdx && score > 0;
                final color = score >= 50
                    ? ReportColors.teal
                    : (score >= 15 ? ReportColors.gold : ReportColors.muted);

                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      if (isBest)
                        pw.Container(
                          width: 3,
                          height: 3,
                          margin: const pw.EdgeInsets.only(bottom: 2),
                          decoration: const pw.BoxDecoration(
                            color: ReportColors.gold,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                      pw.Container(
                        height: barHeight,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: pw.BoxDecoration(
                          color: color,
                          borderRadius: pw.BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHabitBreakdown(
    HabitReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontSemi,
  ) {
    final allHabits = <String, int>{};
    final habitTypes = <String, String>{};

    for (final entry in data.taskTotals.entries) {
      allHabits[entry.key] = entry.value;
      habitTypes[entry.key] = 'task';
    }
    for (final entry in data.prayerTotals.entries) {
      allHabits[entry.key] = entry.value;
      habitTypes[entry.key] = 'prayer';
    }

    final sortedHabits = allHabits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final strongest = data.strongestHabit;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: ReportColors.cardBg,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: ReportColors.border, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'INDIVIDUAL HABIT PERFORMANCE · PROXIMITY TO GOAL',
                style: pw.TextStyle(
                  color: ReportColors.teal,
                  fontSize: 8.5,
                  font: fontBold,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Row(
                children: [
                  pw.Container(width: 6, height: 6, color: ReportColors.teal),
                  pw.SizedBox(width: 3),
                  pw.Text('Tasks',
                      style: pw.TextStyle(
                          color: ReportColors.text2,
                          fontSize: 7.5,
                          font: fontRegular)),
                  pw.SizedBox(width: 8),
                  pw.Container(width: 6, height: 6, color: ReportColors.gold),
                  pw.SizedBox(width: 3),
                  pw.Text('Prayers',
                      style: pw.TextStyle(
                          color: ReportColors.text2,
                          fontSize: 7.5,
                          font: fontRegular)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Column(
            children: sortedHabits.map((entry) {
              final count = entry.value;
              final isTask = habitTypes[entry.key] == 'task';
              final color = isTask ? ReportColors.teal : ReportColors.gold;
              final isStrongest = entry.key == strongest;
              final remaining = data.totalDays - count;

              String label;
              PdfColor labelColor;
              if (count == 0) {
                label = '0/${data.totalDays} · Start here';
                labelColor = ReportColors.muted;
              } else if (count >= data.totalDays * 0.8) {
                label = '$count/${data.totalDays} · $remaining to perfect';
                labelColor = ReportColors.text;
              } else {
                label = '$count/${data.totalDays} · $remaining to build';
                labelColor = ReportColors.text2;
              }

              final doneFlex = (count.clamp(1, data.totalDays));
              final remainingFlex = (data.totalDays - count).clamp(0, data.totalDays);

              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 100,
                      child: pw.Text(
                        entry.key,
                        maxLines: 1,
                        style: pw.TextStyle(
                          color: ReportColors.text,
                          fontSize: 7.8,
                          font: isStrongest ? fontBold : fontSemi,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        height: 7,
                        decoration: pw.BoxDecoration(
                          color: ReportColors.darkBg,
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: doneFlex,
                              child: pw.Container(
                                decoration: pw.BoxDecoration(
                                  color: color,
                                  borderRadius: pw.BorderRadius.circular(2),
                                  border: isStrongest
                                      ? pw.Border.all(color: ReportColors.gold, width: 1)
                                      : null,
                                ),
                              ),
                            ),
                            if (remainingFlex > 0)
                              pw.Expanded(
                                flex: remainingFlex,
                                child: pw.SizedBox(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      width: 95,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        label,
                        style: pw.TextStyle(
                          color: labelColor,
                          fontSize: 7.2,
                          font: count >= data.totalDays * 0.8 ? fontBold : fontRegular,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFutureSelfCard(
    HabitReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontSemi,
  ) {
    final strongest = data.strongestHabit;
    final count = ({...data.taskTotals, ...data.prayerTotals})[strongest] ?? 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: ReportColors.cardBg2,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: ReportColors.gold, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'A Note for Next Month\'s You',
            style: pw.TextStyle(
              color: ReportColors.gold,
              fontSize: 9,
              font: fontBold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'You completed $strongest $count times. That\'s not chance — that\'s identity.',
            style: pw.TextStyle(
              color: ReportColors.text,
              fontSize: 8,
              font: fontSemi,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Keep your anchor habits steady. Your future self is already grateful.',
            style: pw.TextStyle(
              color: ReportColors.text2,
              fontSize: 7.2,
              font: fontRegular,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildOneChangeCard(
    HabitReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontSemi,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: ReportColors.cardBg2,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: ReportColors.teal, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'One High-Leverage Shift',
            style: pw.TextStyle(
              color: ReportColors.teal,
              fontSize: 9,
              font: fontBold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            data.oneChangeInsight,
            style: pw.TextStyle(
              color: ReportColors.text,
              fontSize: 8,
              font: fontSemi,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'One small action. One massive shift. Start tomorrow.',
            style: pw.TextStyle(
              color: ReportColors.text2,
              fontSize: 7.2,
              font: fontRegular,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinItem {
  final String title;
  final String value;
  final String subtitle;
  final PdfColor color;

  _WinItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}
