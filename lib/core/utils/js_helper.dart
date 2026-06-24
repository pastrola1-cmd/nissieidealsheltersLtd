import 'js_helper_stub.dart'
    if (dart.library.js) 'js_helper_web.dart' as js_impl;

void initFacebookPixel(String pixelId) {
  js_impl.initFacebookPixel(pixelId);
}

void trackFacebookPixel(
  String eventName, {
  required String eventId,
  Map<String, dynamic>? data,
}) {
  js_impl.trackFacebookPixel(eventName, eventId: eventId, data: data);
}

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
}) {
  js_impl.trackFacebookCapi(
    pixelId: pixelId,
    capiToken: capiToken,
    eventName: eventName,
    eventId: eventId,
    sourceUrl: sourceUrl,
    leadName: leadName,
    leadPhone: leadPhone,
    leadEmail: leadEmail,
    propertyValue: propertyValue,
    propertyName: propertyName,
  );
}

void registerYouTubePlayerView(String viewType, String videoId) {
  js_impl.registerYouTubePlayerView(viewType, videoId);
}

void initYouTubeVideoTracking(String iframeId, String videoId, void Function(String) onProgress) {
  js_impl.initYouTubeVideoTracking(iframeId, videoId, onProgress);
}

void registerHtml5VideoPlayerView(String viewType, String videoUrl) {
  js_impl.registerHtml5VideoPlayerView(viewType, videoUrl);
}

void initHtml5VideoTracking(String elementId, void Function(String) onProgress) {
  js_impl.initHtml5VideoTracking(elementId, onProgress);
}

String getBrowserHostname() {
  return js_impl.getBrowserHostname();
}

