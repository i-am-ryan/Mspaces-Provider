import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level handler required by firebase_messaging for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled silently; the notification is shown by FCM directly.
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'mspaces_provider_channel',
    'Mspaces Provider',
    description: 'Job and booking notifications',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS + Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create Android notification channel
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Initialise local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings:
          const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && onNotificationTap != null) {
          onNotificationTap!(details.payload);
        }
      },
    );

    // Save token once on startup
    await saveToken();

    // Refresh token whenever FCM rotates it
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => saveToken());

    // Show banner for foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  static void _handleTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final bookingId = data['bookingId'];
    final invoiceId = data['invoiceId'];

    String payload = '';
    switch (type) {
      case 'quote_accepted':
      case 'new_booking':
      case 'booking_confirmed':
      case 'payment_received':
        payload = 'job:${bookingId ?? ''}';
        break;
      case 'deposit_required':
      case 'deposit_invoice':
        payload = 'earnings:${invoiceId ?? ''}';
        break;
      case 'new_job_request':
        payload = 'requests';
        break;
      default:
        payload = 'notifications';
    }
    if (onNotificationTap != null) onNotificationTap!(payload);
  }

  /// Call this after sign-in / registration so the token is saved.
  static Future<void> saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final tokenData = {'fcmToken': token};
    final firestore = FirebaseFirestore.instance;

    // Write to both collections; use set+merge so missing docs don't error
    await Future.wait([
      firestore
          .collection('users')
          .doc(uid)
          .set(tokenData, SetOptions(merge: true)),
      firestore
          .collection('service_providers')
          .doc(uid)
          .set(tokenData, SetOptions(merge: true)),
    ]);
  }

  static void Function(String? payload)? onNotificationTap;

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    String? title = notification?.title ?? data['title'];
    String? body = notification?.body ?? data['body'];

    if (title == null || body == null) {
      switch (data['type']) {
        case 'quote_accepted':
          title ??= 'Quote Accepted!';
          body ??= 'A client accepted your quote.';
          break;
        case 'new_booking':
          title ??= 'New Booking!';
          body ??= 'You have a new booking request.';
          break;
        case 'booking_confirmed':
          title ??= 'Booking Confirmed';
          body ??= 'A booking has been confirmed.';
          break;
        case 'payment_received':
          title ??= 'Payment Received!';
          body ??= 'A payment has been confirmed.';
          break;
        case 'deposit_required':
          title ??= 'Deposit Invoice';
          body ??= 'A deposit invoice has been generated.';
          break;
        case 'new_job_request':
          title ??= 'New Job Request';
          body ??= 'You have a new job request.';
          break;
        default:
          title ??= 'Mspaces';
          body ??= 'You have a new notification.';
      }
    }

    await _local.show(
      id: notification?.hashCode ?? message.messageId.hashCode,
      title: title,
      body: body,
      payload: data['bookingId'] ?? data['invoiceId'] ?? data['quoteRequestId'],
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
