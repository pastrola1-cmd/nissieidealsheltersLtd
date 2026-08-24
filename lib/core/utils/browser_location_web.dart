import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'location_helper.dart';

Future<LocationResult> getBrowserCoordinates() async {
  final completer = Completer<LocationResult>();

  try {
    final geolocation = web.window.navigator.geolocation;
    geolocation.getCurrentPosition(
      ((web.GeolocationPosition pos) {
        if (!completer.isCompleted) {
          final lat = pos.coords.latitude.toDouble();
          final lng = pos.coords.longitude.toDouble();
          final accuracy = pos.coords.accuracy.toDouble();
          completer.complete(
            LocationResult(
              latitude: lat,
              longitude: lng,
              accuracy: accuracy,
            ),
          );
        }
      }).toJS,
      ((web.GeolocationPositionError err) {
        if (!completer.isCompleted) {
          String msg = 'Unable to get location.';
          if (err.code == 1) {
            msg = 'Location permission denied. Please allow location access in your browser to clock in.';
          } else if (err.code == 2) {
            msg = 'Position unavailable. Please ensure your device GPS / location is turned on.';
          } else if (err.code == 3) {
            msg = 'Location request timed out. Please try again.';
          }
          completer.complete(LocationResult.error(msg));
        }
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 60000,
      ),
    );
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(LocationResult.error('Geolocation error: $e'));
    }
  }

  return completer.future;
}
