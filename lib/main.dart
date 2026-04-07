import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils/app_theme.dart';
import 'widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? _missingEnv('SUPABASE_URL'),
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? _missingEnv('SUPABASE_ANON_KEY'),
  );

  runApp(const ExamAIApp());
}

Never _missingEnv(String key) {
  throw StateError('$key is missing in .env');
}

class ExamAIApp extends StatelessWidget {
  const ExamAIApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: home ?? const AuthGate(),
    );
  }
}
