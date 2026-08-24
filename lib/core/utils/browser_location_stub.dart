import 'location_helper.dart';

Future<LocationResult> getBrowserCoordinates() async {
  return const LocationResult.error('Geolocation is only supported in browser/web environment.');
}
