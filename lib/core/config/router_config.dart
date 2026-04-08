import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/provider/notifications/provider_notifications_screen.dart';
import '../../presentation/screens/provider/onboarding/provider_onboarding_screen.dart';
import '../../presentation/screens/provider/jobs/create_quote_screen.dart';
import '../../presentation/screens/provider/earnings/provider_invoice_detail_screen.dart';
import '../../presentation/screens/provider/jobs/provider_quote_detail_screen.dart';
import '../../presentation/screens/provider/splash/splash_screen.dart';
import '../../presentation/screens/provider/auth/provider_login_screen.dart';
import '../../presentation/screens/provider/auth/provider_register_screen.dart';
import '../../presentation/screens/provider/auth/provider_verification_screen.dart';
import '../../presentation/screens/provider/dashboard/provider_dashboard_screen.dart';
import '../../presentation/screens/provider/jobs/job_requests_screen.dart';
import '../../presentation/screens/provider/jobs/active_jobs_screen.dart';
import '../../presentation/screens/provider/jobs/job_detail_screen.dart';
import '../../presentation/screens/provider/jobs/job_history_screen.dart';
import '../../presentation/screens/provider/jobs/accept_job_screen.dart';
import '../../presentation/screens/provider/schedule/provider_calendar_screen.dart';
import '../../presentation/screens/provider/schedule/availability_settings_screen.dart';
import '../../presentation/screens/provider/earnings/provider_earnings_screen.dart';
import '../../presentation/screens/provider/earnings/transactions_screen.dart';
import '../../presentation/screens/provider/earnings/payout_settings_screen.dart';
import '../../presentation/screens/provider/profile/provider_profile_screen.dart';
import '../../presentation/screens/provider/services/services_management_screen.dart';
import '../../presentation/screens/provider/chat/chat_detail_screen.dart';

const _publicRoutes = {
  '/splash',
  '/login',
  '/provider-login',
  '/provider-register',
  '/provider-verification',
};

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final loc = state.matchedLocation;

      if (!isLoggedIn && !_publicRoutes.contains(loc)) {
        return '/provider-login';
      }
      if (isLoggedIn && (loc == '/login' || loc == '/provider-login')) {
        return '/provider-dashboard';
      }
      return null;
    },
    routes: [
      // ── Splash ──────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth ────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const ProviderLoginScreen(),
      ),
      GoRoute(
        path: '/provider-login',
        name: 'provider-login',
        builder: (context, state) => const ProviderLoginScreen(),
      ),
      GoRoute(
        path: '/provider-register',
        name: 'provider-register',
        builder: (context, state) => const ProviderRegisterScreen(),
      ),
      GoRoute(
        path: '/provider-verification',
        name: 'provider-verification',
        builder: (context, state) => const ProviderVerificationScreen(),
      ),
      GoRoute(
        path: '/provider-onboarding',
        name: 'provider-onboarding',
        builder: (context, state) => const ProviderOnboardingScreen(),
      ),

      // ── Dashboard ───────────────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const ProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/provider-dashboard',
        name: 'provider-dashboard',
        builder: (context, state) => const ProviderDashboardScreen(),
      ),

      // ── Jobs ────────────────────────────────────────────────────
      GoRoute(
        path: '/provider-job-requests',
        name: 'provider-job-requests',
        builder: (context, state) => const JobRequestsScreen(),
      ),
      GoRoute(
        path: '/provider-active-jobs',
        name: 'provider-active-jobs',
        builder: (context, state) => const ActiveJobsScreen(),
      ),
      GoRoute(
        path: '/provider-job-detail',
        name: 'provider-job-detail',
        builder: (context, state) {
          final bookingId = state.extra as String? ?? '';
          return JobDetailScreen(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/provider-quote-detail/:id',
        builder: (context, state) => ProviderQuoteDetailScreen(
          quoteRequestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/provider-create-quote',
        name: 'provider-create-quote',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return CreateQuoteScreen(data: data);
        },
      ),
      GoRoute(
        path: '/provider-job-history',
        name: 'provider-job-history',
        builder: (context, state) => const JobHistoryScreen(),
      ),
      GoRoute(
        path: '/provider-accept-job',
        name: 'provider-accept-job',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return AcceptJobScreen(job: data);
        },
      ),
      GoRoute(
        path: '/invoice-detail',
        name: 'invoice-detail',
        builder: (context, state) {
          final invoiceId = state.extra as String? ?? '';
          return ProviderInvoiceDetailScreen(invoiceId: invoiceId);
        },
      ),

      // ── Chat ────────────────────────────────────────────────
      GoRoute(
        path: '/provider-chat-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ChatDetailScreen(
            conversationId: extra['conversationId'] as String,
            otherName: extra['otherName'] as String,
            otherRole: extra['otherRole'] as String,
          );
        },
      ),

      // ── Schedule ────────────────────────────────────────────────
      GoRoute(
        path: '/provider-calendar',
        name: 'provider-calendar',
        builder: (context, state) => const ProviderCalendarScreen(),
      ),
      GoRoute(
        path: '/provider-availability',
        name: 'provider-availability',
        builder: (context, state) => const AvailabilitySettingsScreen(),
      ),

      // ── Earnings ────────────────────────────────────────────────
      GoRoute(
        path: '/provider-earnings',
        name: 'provider-earnings',
        builder: (context, state) => const ProviderEarningsScreen(),
      ),
      GoRoute(
        path: '/provider-transactions',
        name: 'provider-transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),
      GoRoute(
        path: '/provider-payout-settings',
        name: 'provider-payout-settings',
        builder: (context, state) => const PayoutSettingsScreen(),
      ),

      // ── Profile ─────────────────────────────────────────────────
      GoRoute(
        path: '/provider-profile',
        name: 'provider-profile',
        builder: (context, state) => const ProviderProfileScreen(),
      ),

      // ── Services ────────────────────────────────────────────────
      GoRoute(
        path: '/provider-services',
        name: 'provider-services',
        builder: (context, state) => const ServicesManagementScreen(),
      ),
      GoRoute(
        path: '/provider-add-service',
        name: 'provider-add-service',
        builder: (context, state) => const ServicesManagementScreen(),
      ),

      // ── Notifications (placeholder → dashboard) ─────────────────
      GoRoute(
        path: '/provider-notifications',
        name: 'provider-notifications',
        builder: (context, state) => const ProviderNotificationsScreen(),
      ),

      // ── Chat (placeholder → dashboard) ──────────────────────────
      GoRoute(
        path: '/provider-chat-list',
        name: 'provider-chat-list',
        builder: (context, state) => const ProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/provider-chat-detail',
        name: 'provider-chat-detail',
        builder: (context, state) => const ProviderDashboardScreen(),
      ),
    ],
  );
}
