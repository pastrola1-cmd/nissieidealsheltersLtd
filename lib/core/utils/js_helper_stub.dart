void initFacebookPixel(String pixelId) {}

void trackFacebookPixel(
  String eventName, {
  required String eventId,
  Map<String, dynamic>? data,
}) {}

void trackFacebookCapi({
  required String pixelId,
  required String capiToken,
  required String eventName,
  required String eventId,
  required String sourceUrl,
  required String leadName,
  required String leadPhone,
  String? leadEmail,
  double? propertyValue,
  String? propertyName,
}) {}

void registerYouTubePlayerView(String viewType, String videoId) {}

void initYouTubeVideoTracking(String iframeId, String videoId, void Function(String) onProgress) {}

void registerHtml5VideoPlayerView(String viewType, String videoUrl) {}

void initHtml5VideoTracking(String elementId, void Function(String) onProgress) {}

String getBrowserHostname() => '';

