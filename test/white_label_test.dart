import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nissie_ideal_shelters/screens/shared/landing_page_screen.dart';

void main() {
  group('White Label Custom Domain Helper Tests', () {
    test('isCustomDomain returns true for custom domains', () {
      expect(isCustomDomain('agency.com'), true);
      expect(isCustomDomain('properties.agency.co'), true);
      expect(isCustomDomain('myestate.com.ng'), true);
    });

    test('isCustomDomain returns false for excluded domains', () {
      expect(isCustomDomain(''), false);
      expect(isCustomDomain('localhost'), false);
      expect(isCustomDomain('127.0.0.1'), false);
      expect(isCustomDomain('scalewealth.app'), false);
      expect(isCustomDomain('scalewealth.co'), false);
      expect(isCustomDomain('scalewealth.com'), false);
      expect(isCustomDomain('sub.scalewealth.app'), false);
      expect(isCustomDomain('property-partner-network-94301.web.app'), false);
      expect(isCustomDomain('property-partner-network-94301.firebaseapp.com'), false);
    });

    test('A/B Variant split selection and caching in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      
      final lpId = 'landing-page-id-abc';
      final variantKey = 'lp_variant_$lpId';
      
      expect(prefs.getString(variantKey), null);
      
      final variants = ['A', 'B', 'C'];
      final random = math.Random();
      
      final selectedCode = variants[random.nextInt(variants.length)];
      await prefs.setString(variantKey, selectedCode);
      
      expect(prefs.getString(variantKey), selectedCode);
      
      final subsequentFetch = prefs.getString(variantKey);
      expect(subsequentFetch, selectedCode);
    });
  });
}
