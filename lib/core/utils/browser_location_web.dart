import 'dart:async';
import 'dart:html' as html;
import 'location_helper.dart';

Future<LocationResult> getBrowserCoordinates() async {
  final completer = Completer<LocationResult>();

  try {
    if (html.window.navigator.geolocation == null) {
      return const LocationResult.error('Geolocation is not supported by your browser.');
    }

    html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 12),
      maximumAge: const Duration(minutes: 1),
    ).then((pos) {
      if (!completer.isCompleted) {
        final lat = pos.coords?.latitude?.toDouble() ?? 0.0;
        final lng = pos.coords?.longitude?.toDouble() ?? 0.0;
        final acc = pos.coords?.accuracy?.toDouble();
        completer.complete(
          LocationResult(
            latitude: lat,
            longitude: lng,
            accuracy: acc,
          ),
        );
      }
    }).catchError((dynamic err) {
      if (!completer.isCompleted) {
        String msg = 'Unable to get location.';
        final errStr = err.toString();
        if (errStr.contains('PERMISSION_DENIED') || errStr.contains('1')) {
          msg = 'Location permission denied. Please allow location access in your browser settings to clock in.';
        } else if (errStr.contains('POSITION_UNAVAILABLE') || errStr.contains('2')) {
          msg = 'Position unavailable. Please ensure your device GPS / location service is turned ON.';
        } else if (errStr.contains('TIMEOUT') || errStr.contains('3')) {
          msg = 'Location request timed out. Please check your GPS signal and try again.';
        } else {
          msg = errStr;
        }
        completer.complete(LocationResult.error(msg));
      }
    });
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(LocationResult.error('Geolocation error: $e'));
    }
  }

  return completer.future;
}
