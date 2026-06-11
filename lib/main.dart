import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ppn/config/supabase_config.dart';
import 'package:ppn/config/routes.dart';
import 'package:ppn/core/theme/app_theme.dart';
import 'package:ppn/core/constants/app_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI ──
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Lock orientation to portrait ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Load environment variables ──
  await dotenv.load(fileName: 'env.txt');

  // ── Initialize Supabase ──
  await SupabaseConfig.initialize();

  // ── Initialize SharedPreferences ──
  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  // ── Run app ──
  runApp(
    ProviderScope(
      overrides: [
        onboardingCompletedProvider.overrideWithValue(onboardingCompleted),
      ],
      child: const PPNApp(),
    ),
  );
}

/// Root application widget
class PPNApp extends ConsumerWidget {
  const PPNApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appFullName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
