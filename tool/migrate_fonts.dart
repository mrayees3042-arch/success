import 'dart:io';

void main() {
  final filesToMigrate = [
    'lib/main.dart',
    'lib/screens/life_plan_screen.dart',
    'lib/screens/boot_screen.dart',
    'lib/screens/onboarding_screen.dart',
    'lib/services/psychology_report_service.dart',
    'lib/widgets/todo_tile.dart',
  ];

  for (final filePath in filesToMigrate) {
    final file = File(filePath);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();

    // Ensure import of AppFonts if not present
    if (!content.contains('app_fonts.dart')) {
      if (filePath == 'lib/main.dart') {
        content = "import 'core/app_fonts.dart';\n$content";
      } else {
        content = "import '../core/app_fonts.dart';\n$content";
      }
    }

    content = content.replaceAll('GoogleFonts.syne(', 'AppFonts.display(');
    content = content.replaceAll('GoogleFonts.dmSans(', 'AppFonts.text(');
    content = content.replaceAll('GoogleFonts.cairo(', 'AppFonts.arabic(');
    content = content.replaceAll('GoogleFonts.amiri(', 'AppFonts.arabic(');

    file.writeAsStringSync(content);
    print('Migrated $filePath to AppFonts');
  }
}
