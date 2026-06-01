import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Wraps `flutter_local_notifications` for recurring-transaction reminders.
///
/// Notifications are a native (Android/iOS) capability. On web — where there's
/// no plugin support — every method is a genuine no-op and [isSupported] is
/// false, so the UI can hide the feature rather than show something that
/// silently does nothing. This is real platform detection, not a fake stub.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'duitku_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'Reminders for upcoming recurring transactions';

  bool _initialized = false;

  /// Only mobile platforms support local notifications in this app.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!isSupported || _initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(_resolveLocalLocation());

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  /// Requests the OS notification permission. Returns whether it was granted.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  /// Schedules a one-off reminder at [when]. No-op on unsupported platforms or
  /// for past dates.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!isSupported) return;
    await init();
    if (!when.isAfter(DateTime.now())) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) async {
    if (!isSupported) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await _plugin.cancelAll();
  }

  /// Picks a timezone whose current UTC offset matches the device's, so zoned
  /// notifications fire at the user's local wall-clock time. Falls back to UTC.
  /// This avoids a native timezone-name plugin and the build issues it brings.
  tz.Location _resolveLocalLocation() {
    final offset = DateTime.now().timeZoneOffset;
    final nowUtc = DateTime.now().toUtc();
    for (final location in tz.timeZoneDatabase.locations.values) {
      final there = tz.TZDateTime.from(nowUtc, location);
      if (there.timeZoneOffset == offset) return location;
    }
    return tz.getLocation('UTC');
  }
}
