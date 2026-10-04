import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/app/app.dart';
import 'package:whispers_of_joppa/app/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the logger — no print() anywhere else in the app.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord record) {
    debugPrint('[${record.level.name}] ${record.loggerName}: ${record.message}');
  });

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: WhispersApp()));
}
