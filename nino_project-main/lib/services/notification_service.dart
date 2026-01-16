import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';


class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'medicine_reminders';
  static const String _channelName = 'Medicine Reminders';
  static const String _channelDescription =
      'Notifications for scheduled medicine doses';

  static Future<void> initialize() async {
    // Init settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Android permissions (Android 13+)
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // Exact alarms permission (needed for exact timing on modern Android)
    await androidPlugin?.requestExactAlarmsPermission();

    // iOS permissions
    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ✅ Timezone: MUST use device timezone (NOT UTC)
  tz.initializeTimeZones();

String tzName = 'UTC';
try {
  const channel = MethodChannel('app.timezone');
  tzName = await channel.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
} catch (_) {
  // fallback to UTC if something goes wrong
}

tz.setLocalLocation(tz.getLocation(tzName));


    // ✅ Create Android notification channel explicitly (recommended)
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  /// Optional: Quick test to confirm notifications work
  static Future<void> testInOneMinute() async {
    final canScheduleExact =
        await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.canScheduleExactNotifications() ??
            false;

    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

    await _plugin.zonedSchedule(
      999999,
      'Test notification',
      'This should fire in 1 minute',
      when,
      details,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // no need for matchDateTimeComponents for one-time
    );
  }

  static Future<void> scheduleMedicineReminders({
    required int medicineId,
    required String medicineName,
    String? childName,
    required List<TimeOfDay> doseTimes,
    required int durationDays,
  }) async {
    if (doseTimes.isEmpty || durationDays <= 0) return;

    // Use tz.local-aware "now"
    final now = tz.TZDateTime.now(tz.local);
    final start = tz.TZDateTime(tz.local, now.year, now.month, now.day);

    final canScheduleExact =
        await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.canScheduleExactNotifications() ??
            false;

    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    var index = 0;
    for (var day = 0; day < durationDays; day++) {
      final date = start.add(Duration(days: day));

      for (final time in doseTimes) {
        // Build a TZDateTime directly in the local timezone
        final scheduled = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        // If it's already past, skip
        if (scheduled.isBefore(now)) continue;

        final id = medicineId * 10000 + index;
        index += 1;

        final title = 'Medicine reminder';
        final childSuffix =
            (childName == null || childName.trim().isEmpty) ? '' : ' ($childName)';
        final body = 'It is time for $medicineName$childSuffix';

        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  static Future<void> cancelMedicineReminders({
    required int medicineId,
    required int totalNotifications,
  }) async {
    for (var i = 0; i < totalNotifications; i++) {
      final id = medicineId * 10000 + i;
      await _plugin.cancel(id);
    }
  }
}
