import 'package:flutter_test/flutter_test.dart';
import 'package:ppn/core/intelligence/intelligence.dart';
import 'package:ppn/models/models.dart';

void main() {
  group('CityRegistry Tests', () {
    test('Resolves exact case-insensitive queries', () {
      final lagos = CityRegistry.get('Lagos');
      expect(lagos.id, 'lagos');
      expect(lagos.name, 'Lagos');
      expect(lagos.neighborhoods, contains('Lekki'));

      final abuja = CityRegistry.get('abuja  ');
      expect(abuja.id, 'abuja');
      expect(abuja.name, 'Abuja');
      expect(abuja.neighborhoods, contains('Maitama'));

      final ph = CityRegistry.get('PORT_HARCOURT');
      expect(ph.id, 'port_harcourt');
      expect(ph.name, 'Port Harcourt');
      expect(ph.neighborhoods, contains('GRA Phase 1'));
    });

    test('Successfully falls back to the Nigeria default profile', () {
      final fallback = CityRegistry.get('Kano');
      expect(fallback.id, 'nigeria_default');
      expect(fallback.name, 'Nigeria');
      expect(fallback.neighborhoods, contains('Default Development'));
    });

    test('getAll returns all 3 primary cities', () {
      final all = CityRegistry.getAll();
      expect(all.length, 3);
      final names = all.map((c) => c.id).toList();
      expect(names, containsAll(['lagos', 'abuja', 'port_harcourt']));
    });
  });

  group('AudienceRegistry Tests', () {
    test('Resolves all 5 profiles without null fields', () {
      final profiles = ['investor', 'family', 'diaspora', 'luxury', 'first_time'];
      for (final id in profiles) {
        final profile = AudienceRegistry.get(id);
        expect(profile, isNotNull);
        expect(profile!.id, id);
        expect(profile.label, isNotEmpty);
        expect(profile.intentSignals, isNotEmpty);
        expect(profile.messagingAngle, isNotEmpty);
        expect(profile.ctaStyle, isNotEmpty);
        expect(profile.triggerWords, isNotEmpty);
      }
    });

    test('Returns null for unknown profile', () {
      final profile = AudienceRegistry.get('unknown');
      expect(profile, isNull);
    });

    test('getAll returns all 5 audience profiles', () {
      final all = AudienceRegistry.getAll();
      expect(all.length, 5);
    });
  });

  group('Property Model Target Audience Tests', () {
    test('Correctly serializes and deserializes target_audience JSON field', () {
      final json = {
        'id': 'prop-123',
        'company_id': 'comp-123',
        'title': 'Stunning Lekki Duplex',
        'description': 'Description',
        'location': 'Lagos',
        'price': 250000000.0,
        'status': 'available',
        'images': <String>[],
        'video_url': null,
        'assigned_partner_id': null,
        'created_by': null,
        'commission_type': 'percentage',
        'commission_value': 5.0,
        'target_audience': 'diaspora',
        'created_at': '2026-06-11T10:00:00.000Z',
        'updated_at': '2026-06-11T10:00:00.000Z',
      };

      final property = Property.fromJson(json);
      expect(property.targetAudience, 'diaspora');

      final backToJson = property.toJson();
      expect(backToJson['target_audience'], 'diaspora');

      // Test copyWith targetAudience manipulation
      final updated = property.copyWith(targetAudience: 'investor');
      expect(updated.targetAudience, 'investor');

      final cleared = property.copyWith(targetAudience: null);
      expect(cleared.targetAudience, isNull);

      final unchanged = property.copyWith();
      expect(unchanged.targetAudience, 'diaspora');
    });
  });
}
