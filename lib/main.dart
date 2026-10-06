import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/app/app.dart';
import 'package:whispers_of_joppa/app/config.dart';
import 'package:whispers_of_joppa/app/crash_reporting.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the logger — no print() anywhere else in the app.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
  });

  // Crash reports and analytics. The game runs the same without them.
  // Device tests switch the live services off: they report nothing.
  if (WhispersApp.accountsEnabled) {
    WhispersApp.analytics = await startCrashReporting();
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: WhispersApp()));
}
