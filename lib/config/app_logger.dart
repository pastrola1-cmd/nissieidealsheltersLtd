import 'package:flutter/foundation.dart';

final List<String> globalLogBuffer = [];

void logDebug(String message) {
  final log = '${DateTime.now().toIso8601String().substring(11, 19)}: $message';
  globalLogBuffer.add(log);
  debugPrint(message);
}
