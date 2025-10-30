import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy-first Crash Reporting Service
///
/// Integrates with:
/// - Sentry (crash reporting) → works with self-hosted GlitchTip
///
/// Features:
/// - Opt-in by default (respects user privacy)
/// - No PII (Personally Identifiable Information)
/// - Self-hostable on Easypanel
/// - Catches silent crashes that logs miss
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _initialized = false;
  bool _enabled = false;

  // Self-hosted GlitchTip (Sentry-compatible crash reporting)
  static const String? _sentryDsn =
      'https://1c067b18cd32421e83ec2512d9e649d5@trust-tune-trust-tune-glitchtip.62ickh.easypanel.host/1';

  /// Mark analytics as initialized (called from main.dart after SentryFlutter.init)
  /// NOTE: Actual Sentry initialization happens in main.dart with SentryFlutter.init()
  Future<void> markAsInitialized() async {
    if (_initialized) return;

    // Load user preference
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('analytics_enabled') ?? false; // Default: OFF (privacy-first)

    _initialized = true;
    debugPrint('[Analytics] Marked as initialized (enabled: $_enabled)');
    debugPrint('[Analytics] Sentry initialization handled by main.dart (SentryFlutter.init)');
  }

  /// Enable/disable analytics (user preference)
  /// NOTE: Requires app restart to take effect (SentryFlutter.init runs on startup)
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analytics_enabled', enabled);
    debugPrint('[Analytics] User preference set to: $enabled (requires restart)');
  }

  /// Get current enabled status
  bool get isEnabled => _enabled;

  /// Track an event (usage analytics) - adds breadcrumb to crash reports
  ///
  /// Music player events:
  /// - 'song_played', 'song_paused', 'song_skipped'
  /// - 'search_performed', 'download_started', 'download_completed'
  /// - 'library_scanned', 'playlist_created', 'favorite_added'
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    if (!_enabled || !_initialized) return;

    try {
      // Create breadcrumb in Sentry for crash context
      if (_sentryDsn != null) {
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: eventName,
            data: properties,
            category: 'user_action',
            level: SentryLevel.info,
          ),
        );
      }

      debugPrint('[Analytics] Event tracked: $eventName');
    } catch (e) {
      debugPrint('[Analytics] Failed to track event: $e');
    }
  }

  /// Track screen view - adds breadcrumb to crash reports
  void trackScreen(String screenName) {
    if (!_enabled || !_initialized) return;

    try {
      // Add screen breadcrumb to Sentry for crash context
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Screen: $screenName',
          category: 'navigation',
          level: SentryLevel.info,
        ),
      );

      debugPrint('[Analytics] Screen tracked: $screenName');
    } catch (e) {
      debugPrint('[Analytics] Failed to track screen: $e');
    }
  }

  /// Capture error/exception manually
  ///
  /// Use this for handled errors you want to report
  void captureError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? extras,
  }) {
    if (!_enabled || !_initialized) return;

    try {
      if (_sentryDsn != null) {
        Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) {
            if (context != null) {
              scope.setTag('context', context);
            }
            if (extras != null) {
              extras.forEach((key, value) {
                scope.setExtra(key, value);
              });
            }
          },
        );
      }

      debugPrint('[Analytics] Error captured: $error');
    } catch (e) {
      debugPrint('[Analytics] Failed to capture error: $e');
    }
  }

  /// Set user context (anonymous ID only, no PII)
  ///
  /// This helps with crash tracking while maintaining privacy
  void setUserContext({String? anonymousId}) {
    if (!_enabled || !_initialized) return;

    try {
      if (_sentryDsn != null && anonymousId != null) {
        Sentry.configureScope((scope) {
          scope.setUser(SentryUser(id: anonymousId));
        });
      }

      debugPrint('[Analytics] User context set (anonymous)');
    } catch (e) {
      debugPrint('[Analytics] Failed to set user context: $e');
    }
  }

  /// Add custom context to crash reports
  void setContext(String key, dynamic value) {
    if (!_enabled || !_initialized) return;

    try {
      if (_sentryDsn != null) {
        Sentry.configureScope((scope) {
          scope.setContexts(key, value);
        });
      }
    } catch (e) {
      debugPrint('[Analytics] Failed to set context: $e');
    }
  }

  /// Close and flush (call on app termination)
  Future<void> close() async {
    if (!_initialized) return;

    try {
      if (_sentryDsn != null) {
        await Sentry.close();
      }
      debugPrint('[Analytics] Closed and flushed');
    } catch (e) {
      debugPrint('[Analytics] Error during close: $e');
    }
  }
}

/// Music Player Event Names (for consistency)
class AnalyticsEvents {
  // Playback events
  static const String songPlayed = 'song_played';
  static const String songPaused = 'song_paused';
  static const String songSkipped = 'song_skipped';
  static const String songSeeked = 'song_seeked';
  static const String playbackModeChanged = 'playback_mode_changed';

  // Library events
  static const String libraryScanned = 'library_scanned';
  static const String songFavorited = 'song_favorited';
  static const String songRated = 'song_rated';
  static const String albumOpened = 'album_opened';

  // Search & Download events
  static const String searchPerformed = 'search_performed';
  static const String searchResultClicked = 'search_result_clicked';
  static const String downloadStarted = 'download_started';
  static const String downloadCompleted = 'download_completed';
  static const String downloadFailed = 'download_failed';

  // YouTube streaming events
  static const String youtubeStreamStarted = 'youtube_stream_started';
  static const String youtubeStreamFailed = 'youtube_stream_failed';
  static const String youtubeDownloadStarted = 'youtube_download_started';

  // Settings events
  static const String settingsChanged = 'settings_changed';
  static const String analyticsToggled = 'analytics_toggled';
}

/// Screen Names (for consistency)
class AnalyticsScreens {
  static const String home = 'Home';
  static const String search = 'Search';
  static const String library = 'Library';
  static const String nowPlaying = 'Now Playing';
  static const String downloads = 'Downloads';
  static const String settings = 'Settings';
  static const String about = 'About';
}
