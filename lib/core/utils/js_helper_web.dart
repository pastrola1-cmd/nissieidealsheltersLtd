import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

void initFacebookPixel(String pixelId) {
  try {
    // 1. Check if fbq function is already registered in global JS context
    final hasFbq = js.context.hasProperty('fbq');
    if (!hasFbq) {
      final script = '''
        !function(f,b,e,v,n,t,s)
        {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
        n.callMethod.apply(n,arguments):n.queue.push(arguments)};
        if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
        n.queue=[];t=b.createElement(e);t.async=!0;
        t.src=v;s=b.getElementsByTagName(e)[0];
        s.parentNode.insertBefore(t,s)}(window,document,'script',
        'https://connect.facebook.net/en_US/fbevents.js');
      ''';
      js.context.callMethod('eval', [script]);
    }

    // 2. Initialize pixel for the specific agency (prevents global pollution)
    js.context.callMethod('fbq', ['init', pixelId]);
    js.context.callMethod('fbq', ['track', 'PageView']);
  } catch (e) {
    print('Error initializing Facebook Pixel: $e');
  }
}

void trackFacebookPixel(
  String eventName, {
  required String eventId,
  Map<String, dynamic>? data,
}) {
  try {
    if (data != null) {
      js.context.callMethod('fbq', [
        'track',
        eventName,
        js.JsObject.jsify(data),
        js.JsObject.jsify({'eventID': eventId})
      ]);
    } else {
      js.context.callMethod('fbq', [
        'track',
        eventName,
        null,
        js.JsObject.jsify({'eventID': eventId})
      ]);
    }
  } catch (e) {
    print('Error tracking Facebook Pixel event ($eventName): $e');
  }
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
  try {
    // Inject CAPI helper JS function if not already present
    final hasCapiHelper = js.context.hasProperty('_fireMetaCapiEvent');
    if (!hasCapiHelper) {
      final helperScript = '''
        window._fireMetaCapiEvent = async function(config) {
          const { pixelId, capiToken, eventName, eventId, sourceUrl, user, custom } = config;
          
          // Native SHA-256 Hashing helper
          const sha256 = async (str) => {
            if (!str) return null;
            const cleanStr = str.trim().toLowerCase();
            const msgBuffer = new TextEncoder().encode(cleanStr);
            const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
            const hashArray = Array.from(new Uint8Array(hashBuffer));
            return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
          };

          const nameParts = user.name ? user.name.trim().split(/\\s+/) : [];
          const firstName = nameParts[0] || '';
          const lastName = nameParts.slice(1).join(' ') || '';

          const hashedEmail = await sha256(user.email);
          const hashedPhone = await sha256(user.phone);
          const hashedFirstName = await sha256(firstName);
          const hashedLastName = await sha256(lastName);

          const eventPayload = {
            data: [{
              event_name: eventName,
              event_time: Math.floor(Date.now() / 1000),
              event_id: eventId,
              event_source_url: sourceUrl,
              action_source: "website",
              user_data: {
                client_user_agent: navigator.userAgent,
                em: hashedEmail ? [hashedEmail] : [],
                ph: hashedPhone ? [hashedPhone] : [],
                fn: hashedFirstName ? [hashedFirstName] : [],
                ln: hashedLastName ? [hashedLastName] : []
              }
            }]
          };

          if (custom && custom.value) {
            eventPayload.data[0].custom_data = {
              value: custom.value,
              currency: "NGN",
              content_name: custom.contentName || ""
            };
          }

          try {
            const response = await fetch(`https://graph.facebook.com/v19.0/\${pixelId}/events?access_token=\${capiToken}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(eventPayload)
            });
            const result = await response.json();
            console.log('Meta CAPI response:', result);
          } catch (err) {
            console.error('Meta CAPI error:', err);
          }
        };
      ''';
      js.context.callMethod('eval', [helperScript]);
    }

    // Call the JS function asynchronously to avoid blocking Dart main thread
    final config = {
      'pixelId': pixelId,
      'capiToken': capiToken,
      'eventName': eventName,
      'eventId': eventId,
      'sourceUrl': sourceUrl,
      'user': {
        'name': leadName,
        'phone': leadPhone,
        'email': leadEmail,
      },
      'custom': {
        'value': propertyValue,
        'contentName': propertyName,
      }
    };

    js.context.callMethod('_fireMetaCapiEvent', [js.JsObject.jsify(config)]);
  } catch (e) {
    print('Error triggering Meta CAPI: $e');
  }
}

void registerYouTubePlayerView(String viewType, String videoId) {
  try {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$videoId?enablejsapi=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..id = 'youtube-iframe-$videoId';
      return iframe;
    });
  } catch (e) {
    print('Error registering YouTube player view: $e');
  }
}

void initYouTubeVideoTracking(String iframeId, String videoId, void Function(String) onProgress) {
  try {
    js.context['onYouTubeVideoProgress_$videoId'] = (String milestone) {
      onProgress(milestone);
    };

    final hasTracker = js.context.hasProperty('_initYouTubeTracking');
    if (!hasTracker) {
      final script = '''
        window._initYouTubeTracking = function(iframeId, videoId, callbackName) {
          if (!window.YT) {
            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
          }

          function setupPlayer() {
            var player = new YT.Player(iframeId, {
              events: {
                'onStateChange': onPlayerStateChange
              }
            });

            var progressTracked = { '25': false, '50': false, '75': false, '100': false };
            var intervalId = null;

            function onPlayerStateChange(event) {
              if (event.data == YT.PlayerState.PLAYING) {
                if (!intervalId) {
                  intervalId = setInterval(function() {
                    var duration = player.getDuration();
                    var currentTime = player.getCurrentTime();
                    if (duration > 0) {
                      var percent = (currentTime / duration) * 100;
                      ['25', '50', '75', '100'].forEach(function(milestone) {
                        if (percent >= parseInt(milestone) && !progressTracked[milestone]) {
                          progressTracked[milestone] = true;
                          if (typeof window[callbackName] === 'function') {
                            window[callbackName](milestone);
                          }
                        }
                      });
                    }
                  }, 1000);
                }
              } else {
                if (intervalId) {
                  clearInterval(intervalId);
                  intervalId = null;
                }
              }
            }
          }

          if (window.YT && window.YT.Player) {
            setupPlayer();
          } else {
            var oldOnReady = window.onYouTubeIframeAPIReady;
            window.onYouTubeIframeAPIReady = function() {
              if (oldOnReady) oldOnReady();
              setupPlayer();
            };
          }
        };
      ''';
      js.context.callMethod('eval', [script]);
    }

    js.context.callMethod('_initYouTubeTracking', [iframeId, videoId, 'onYouTubeVideoProgress_$videoId']);
  } catch (e) {
    print('Error initializing YouTube tracking: $e');
  }
}

void registerHtml5VideoPlayerView(String viewType, String videoUrl) {
  try {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final video = html.VideoElement()
        ..src = videoUrl
        ..controls = true
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..id = 'html5-video-${viewType.hashCode}';
      return video;
    });
  } catch (e) {
    print('Error registering HTML5 video player view: $e');
  }
}

void initHtml5VideoTracking(String elementId, void Function(String) onProgress) {
  try {
    final callbackKey = 'onHtml5VideoProgress_${elementId.hashCode}';
    js.context[callbackKey] = (String milestone) {
      onProgress(milestone);
    };

    final hasTracker = js.context.hasProperty('_initHtml5VideoTracking');
    if (!hasTracker) {
      final script = '''
        window._initHtml5VideoTracking = function(elementId, callbackName) {
          var video = document.getElementById(elementId);
          if (!video) return;

          var progressTracked = { '25': false, '50': false, '75': false, '100': false };

          video.addEventListener('timeupdate', function() {
            var duration = video.duration;
            var currentTime = video.currentTime;
            if (duration > 0) {
              var percent = (currentTime / duration) * 100;
              ['25', '50', '75', '100'].forEach(function(milestone) {
                if (percent >= parseInt(milestone) && !progressTracked[milestone]) {
                  progressTracked[milestone] = true;
                  if (typeof window[callbackName] === 'function') {
                    window[callbackName](milestone);
                  }
                }
              });
            }
          });
        };
      ''';
      js.context.callMethod('eval', [script]);
    }

    js.context.callMethod('_initHtml5VideoTracking', [elementId, callbackKey]);
  } catch (e) {
    print('Error initializing HTML5 video tracking: $e');
  }
}

String getBrowserHostname() {
  try {
    return html.window.location.hostname ?? '';
  } catch (e) {
    return '';
  }
}

