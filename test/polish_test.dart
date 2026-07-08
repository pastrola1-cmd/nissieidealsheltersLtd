// ignore_for_file: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/config/routes.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Onboarding & Polish Tests', () {
    test('Onboarding status defaults to false and saves to true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      
      bool completed = prefs.getBool('onboarding_completed') ?? false;
      expect(completed, isFalse);

      await prefs.setBool('onboarding_completed', true);
      completed = prefs.getBool('onboarding_completed') ?? false;
      expect(completed, isTrue);
    });

    test('onboardingCompletedProvider reads correct override value', () {
      final container = ProviderContainer(
        overrides: [
          onboardingCompletedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final isCompleted = container.read(onboardingCompletedProvider);
      expect(isCompleted, isTrue);
    });
  });
}
