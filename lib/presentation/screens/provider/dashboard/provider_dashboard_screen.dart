// lib/presentation/screens/provider/screens/dashboard/provider_dashboard_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/common/offers_carousel.dart';
import '../../../widgets/common/banking_details_banner.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Profile ──────────────────────────────────────────────────────────────
  String _displayName = '';
  String _photoUrl = '';
  double _rating = 0;

  // ── Stats ────────────────────────────────────────────────────────────────
  int _weekJobs = 0;
  double _weekEarnings = 0;
  int _pendingCount = 0;
  int _completedWeek = 0;

  bool _loading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (_uid.isEmpty) return;
    setState(() => _loading = true);
    try {
      // ── Profile ────────────────────────────────────────────────────────
      final spSnap = await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(_uid)
          .get();
      final spData = spSnap.data() ?? {};

      final userSnap =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final userData = userSnap.data() ?? {};

      final name = spData['displayName']?.toString() ??
          userData['displayName']?.toString() ??
          FirebaseAuth.instance.currentUser?.displayName ??
          '';
      final photo = spData['profilePhotoUrl']?.toString() ?? '';
      final ratingRaw = spData['averageRating'] ?? spData['rating'] ?? 0.0;
      final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;

      // ── This week range ────────────────────────────────────────────────
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartTs = Timestamp.fromDate(
          DateTime(weekStart.year, weekStart.month, weekStart.day));

      // ── This week's active jobs — no date filter to avoid index issues ─
      // We fetch all active and filter client-side by scheduledDate
      final activeSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _uid)
          .where('status', whereIn: [
        'confirmed',
        'provider_en_route',
        'provider_arrived',
        'in_progress',
        'accepted',
      ]).get();

      // Filter this week client-side
      int weekJobs = 0;
      for (final doc in activeSnap.docs) {
        final data = doc.data();
        final scheduled = _toDateTime(data['scheduledDate']);
        if (scheduled != null && !scheduled.isBefore(weekStartTs.toDate())) {
          weekJobs++;
        } else if (scheduled == null) {
          // If no scheduled date, count it (it's active now)
          weekJobs++;
        }
      }

      // ── Completed this week ────────────────────────────────────────────
      final completedSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _uid)
          .where('status', isEqualTo: 'completed')
          .get();

      int completedWeek = 0;
      double weekEarnings = 0;
      for (final doc in completedSnap.docs) {
        final data = doc.data();
        // Check completedAt or updatedAt or scheduledDate
        final completedAt = _toDateTime(data['completedAt']) ??
            _toDateTime(data['updatedAt']) ??
            _toDateTime(data['scheduledDate']);
        if (completedAt != null &&
            !completedAt.isBefore(weekStartTs.toDate())) {
          completedWeek++;
          final amt =
              data['totalAmount'] ?? data['amount'] ?? data['callOutFee'] ?? 0;
          weekEarnings += (amt as num).toDouble();
        }
      }

      // ── Pending bookings ───────────────────────────────────────────────
      final pendingSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _uid)
          .where('status',
              whereIn: ['pending', 'pending_provider_confirmation']).get();

      // ── Pending quotes ─────────────────────────────────────────────────
      int quoteCount = 0;
      try {
        final quoteSnap = await FirebaseFirestore.instance
            .collection('quote_requests')
            .where('providerId', isEqualTo: _uid)
            .where('status', isEqualTo: 'pending')
            .get();
        quoteCount = quoteSnap.docs.length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _displayName = name;
          _photoUrl = photo;
          _rating = rating;
          _weekJobs = weekJobs;
          _completedWeek = completedWeek;
          _pendingCount = pendingSnap.docs.length + quoteCount;
          _weekEarnings = weekEarnings;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final first = _displayName.trim().split(' ').first;
    return first.isNotEmpty ? first : 'Provider';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BankingDetailsBanner(
      route: '/provider-banking-details',
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            switch (index) {
              case 0:
                break;
              case 1:
                context.push('/provider-job-requests');
                break;
              case 2:
                context.push('/provider-calendar');
                break;
              case 3:
                context.push('/provider-earnings');
                break;
              case 4:
                context.push('/provider-profile');
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.work_outline), label: 'Jobs'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today), label: 'Calendar'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Earnings'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.black))
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  color: Colors.black,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero banner ───────────────────────────────────
                        _buildHeroBanner(),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatsGrid(),
                              const SizedBox(height: 24),
                              _buildQuickActions(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                        // ── Offers ────────────────────────────────────────
                        const OffersCarousel(targetType: 'providers'),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ── Hero Banner
  Widget _buildHeroBanner() {
    final initials = _displayName
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      height: 160,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage(
              'assets/images/benjamin-brunner-imEtY2Kpejk-unsplash.jpg'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.70),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              // Profile picture
              GestureDetector(
                onTap: () => context.push('/provider-profile'),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: _photoUrl.isNotEmpty
                        ? Image.network(_photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _initialsWidget(initials))
                        : _initialsWidget(initials),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_greeting, $_firstName! 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _rating > 0
                          ? '⭐ ${_rating.toStringAsFixed(1)} · Ready for new jobs'
                          : 'Ready to take on new jobs',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Notifications
              Stack(children: [
                IconButton(
                  onPressed: () => context.push('/provider-notifications'),
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 26),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(_uid)
                      .collection('notifications')
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialsWidget(String initials) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  // ── Stats Grid ────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This Week',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _statCard(
              label: "This Week's Jobs",
              value: _weekJobs.toString(),
              icon: Icons.work_outline,
              color: Colors.blue,
              // tab 0 = active/requests
              onTap: () =>
                  context.push('/provider-job-requests', extra: {'tab': 0}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              label: "Week's Earnings",
              value: _weekEarnings > 0
                  ? 'R${_weekEarnings.toStringAsFixed(0)}'
                  : 'R0',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.green,
              onTap: () => context.push('/provider-earnings'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _statCard(
              label: 'Pending Requests\nThis Week',
              value: _pendingCount.toString(),
              icon: Icons.pending_outlined,
              color: Colors.orange,
              // tab 0 = requests/pending
              onTap: () =>
                  context.push('/provider-job-requests', extra: {'tab': 0}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              label: 'Completed\nThis Week',
              value: _completedWeek.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.purple,
              // tab 2 = past
              onTap: () =>
                  context.push('/provider-job-requests', extra: {'tab': 2}),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.arrow_forward_ios,
                size: 10, color: Colors.grey[400]),
          ),
        ]),
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _actionTile(
          icon: Icons.notifications_active_outlined,
          color: Colors.orange,
          title: 'Job Requests',
          subtitle: _pendingCount > 0
              ? '$_pendingCount pending request${_pendingCount == 1 ? '' : 's'}'
              : 'No pending requests',
          onTap: () =>
              context.push('/provider-job-requests', extra: {'tab': 0}),
        ),
        _actionTile(
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.green,
          title: 'Earnings & Payments',
          subtitle: _weekEarnings > 0
              ? 'R${_weekEarnings.toStringAsFixed(0)} this week'
              : 'View your earnings history',
          onTap: () => context.push('/provider-earnings'),
        ),
        _actionTile(
          icon: Icons.history,
          color: Colors.purple,
          title: 'Job History',
          subtitle: '$_completedWeek completed this week',
          // tab 2 = past jobs
          onTap: () =>
              context.push('/provider-job-requests', extra: {'tab': 2}),
        ),
        _actionTile(
          icon: Icons.person_outline,
          color: Colors.blue,
          title: 'My Profile',
          subtitle: 'Edit your profile and services',
          onTap: () => context.push('/provider-profile'),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}
