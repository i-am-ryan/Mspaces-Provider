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

  await NotificationService.initialize();

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
