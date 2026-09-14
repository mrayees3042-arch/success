import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:success/screens/life_plan_screen.dart';

void main() {
  group('Dual-Section Goals & Mind Dump Verification Suite', () {
    test('1. LifeGoal model defaults section to right and serializes correctly', () {
      final goal = LifeGoal(
        id: '1',
        title: 'Master Flutter',
        deadline: 'Dec 2026',
        progress: 0.5,
        color: Colors.blue,
      );

      expect(goal.section, 'right');

      final json = goal.toJson();
      expect(json['section'], 'right');
      expect(json['title'], 'Master Flutter');

      final reconstructed = LifeGoal.fromJson(json);
      expect(reconstructed.section, 'right');
      expect(reconstructed.title, 'Master Flutter');
    });

    test('2. LifeGoal model correctly deserializes left section items', () {
      final leftGoal = LifeGoal(
        id: '2',
        title: 'External market fluctuation',
        deadline: 'Let Go & Parked',
        progress: 0.0,
        color: Colors.cyan,
        section: 'left',
      );

      final json = leftGoal.toJson();
      expect(json['section'], 'left');

      final reconstructed = LifeGoal.fromJson(json);
      expect(reconstructed.section, 'left');
      expect(reconstructed.title, 'External market fluctuation');
    });

    test('3. Legacy goals without section field automatically default to right section (Zero Data Loss)', () {
      final legacyJson = {
        'id': 'legacy_123',
        'title': 'Legacy User Goal',
        'deadline': '2026',
        'progress': 0.8,
        'color': Colors.amber.toARGB32(),
        'isDone': false,
        'subTasks': [
          {'id': 'sub_1', 'title': 'Step 1', 'isDone': true}
        ],
      };

      final goal = LifeGoal.fromJson(legacyJson);
      expect(goal.section, 'right');
      expect(goal.title, 'Legacy User Goal');
      expect(goal.subTasks.length, 1);
      expect(goal.subTasks.first.isDone, true);
    });

    test('4. Moving goal between Left and Right sections updates state cleanly', () {
      final goal = LifeGoal(
        id: '3',
        title: 'Algorithmic ranking change',
        deadline: 'Ongoing',
        progress: 0.0,
        color: Colors.cyan,
        section: 'left',
      );

      expect(goal.section, 'left');

      // Move to Right (I Can Do)
      goal.section = 'right';
      expect(goal.section, 'right');

      // Move back to Left (Out of Control - Let Go)
      goal.section = 'left';
      expect(goal.section, 'left');
    });

    test('5. JSON List filtering separates Left (Let Go) and Right (I Can Do) goals accurately', () {
      final list = [
        LifeGoal(id: '1', title: 'Write Clean Code', deadline: 'Today', progress: 0.0, color: Colors.blue, section: 'right'),
        LifeGoal(id: '2', title: 'Interview Outcome', deadline: 'Let Go', progress: 0.0, color: Colors.blue, section: 'left'),
        LifeGoal(id: '3', title: 'Hit 10k Steps', deadline: 'Daily', progress: 0.0, color: Colors.blue, section: 'right'),
        LifeGoal(id: '4', title: 'Traffic Delay', deadline: 'Let Go', progress: 0.0, color: Colors.blue, section: 'left'),
      ];

      final leftGoals = list.where((g) => g.section == 'left').toList();
      final rightGoals = list.where((g) => g.section == 'right').toList();

      expect(leftGoals.length, 2);
      expect(rightGoals.length, 2);
      expect(leftGoals.map((g) => g.title), containsAll(['Interview Outcome', 'Traffic Delay']));
      expect(rightGoals.map((g) => g.title), containsAll(['Write Clean Code', 'Hit 10k Steps']));
    });
  });
}
