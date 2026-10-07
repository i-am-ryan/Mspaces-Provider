import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/config/router_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init: $e');
  }

  // Never let notification setup block the app from opening
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification init: $e');
  }

  // Handle notification tap routing
  NotificationService.onNotificationTap = (payload) {
    if (payload == null) return;
    final router = AppRouter.router;
    final parts = payload.split(':');
    final route = parts[0];
    final id = parts.length > 1 ? parts[1] : '';

    switch (route) {
      case 'job':
        if (id.isNotEmpty) {
          router.push('/provider-job-detail', extra: id);
        } else {
          router.push('/provider-active-jobs');
        }
        break;
      case 'earnings':
        router.push('/provider-earnings');
        break;
      case 'requests':
        router.push('/provider-job-requests');
        break;
      case 'chat':
        if (id.isEmpty) {
          router.push('/provider-notifications');
          break;
        }
        FirebaseFirestore.instance
            .collection('conversations')
            .doc(id)
            .get()
            .then((doc) {
          final conv = doc.data();
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final otherRole = conv == null
              ? ''
              : ['client', 'provider', 'tenant', 'landlord'].firstWhere(
                  (r) => conv['${r}Id'] != null && conv['${r}Id'] != uid,
                  orElse: () => '');
          if (otherRole.isEmpty) {
            router.push('/provider-notifications');
            return;
          }
          router.push('/provider-chat-detail', extra: {
            'conversationId': id,
            'otherName': conv!['${otherRole}Name']?.toString() ?? '',
            'otherRole': otherRole,
          });
        });
        break;
      case 'notifications':
      default:
        router.push('/provider-notifications');
    }
  };

  runApp(const MspacesProviderApp());
}

class MspacesProviderApp extends StatelessWidget {
  const MspacesProviderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mspaces Provider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
