import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelMeeting  = 'staffsync_meetings';
  static const String _channelReminder = 'staffsync_reminders';
  static const String _channelUrgent   = 'staffsync_urgent';
  static const String _channelChat     = 'staffsync_chat';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createChannels();
    _initialized = true;
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelMeeting,
      'Meeting Reminders',
      description: 'Reminders for upcoming meetings',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelReminder,
      'Reminders',
      description: 'Custom reminders and alerts',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    ));

    await android.createNotificationChannel(AndroidNotificationChannel(
      _channelUrgent,
      'Urgent Notifications',
      description: 'Emergency alerts from staff',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('emergency'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelChat,
      'Chat Messages',
      description: 'Group chat messages',
      importance: Importance.defaultImportance,
      playSound: true,
    ));
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
  }

  Future<void> showMeetingReminder({
    required String title,
    required String body,
    int id = 1,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelMeeting, 'Meeting Reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification'),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showReminder({
    required String title,
    required String body,
    int id = 2,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelReminder, 'Reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showUrgentNotification({
    required String title,
    required String body,
    int id = 3,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: '🚨 $title',
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelUrgent, 'Urgent Notifications',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('emergency'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
          fullScreenIntent: true,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFEF4444),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
    );
  }

  Future<void> showChatMessage({
    required String groupName,
    required String senderName,
    required String message,
    int id = 4,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: '$senderName in $groupName',
      body: message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelChat, 'Chat Messages',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> cancelAll() async => await _plugin.cancelAll();
  Future<void> cancel(int id) async => await _plugin.cancel(id: id);
}