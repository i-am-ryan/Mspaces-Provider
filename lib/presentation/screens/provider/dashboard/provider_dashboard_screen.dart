import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../widgets/common/offers_carousel.dart';
import '../../../widgets/common/banner_notification_overlay.dart';
import '../../../widgets/common/banking_details_banner.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _selectedIndex = 0;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<DocumentSnapshot> get _providerStream => FirebaseFirestore.instance
      .collection('service_providers')
      .doc(_uid)
      .snapshots();

  Stream<QuerySnapshot> get _pendingStream => FirebaseFirestore.instance
      .collection('bookings')
      .where('providerId', isEqualTo: _uid)
      .where('status',
          whereIn: ['pending', 'pending_provider_confirmation']).snapshots();

  Stream<QuerySnapshot> get _pendingQuotesStream => FirebaseFirestore.instance
      .collection('quote_requests')
      .where('providerId', isEqualTo: _uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Stream<QuerySnapshot> get _activeStream => FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _uid)
          .where('status', whereIn: [
        'accepted',
        'confirmed',
        'in_progress',
        'assessment_complete'
      ]).snapshots();

  Stream<QuerySnapshot> get _earningsStream => FirebaseFirestore.instance
      .collection('transactions')
      .doc(_uid)
      .collection('entries')
      .where('status', isEqualTo: 'completed')
      .snapshots();

  List<QueryDocumentSnapshot> _weekJobs(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 7));
    return docs.where((doc) {
      final ts = (doc.data() as Map)['scheduledDate'];
      if (ts is! Timestamp) return false;
      final d = ts.toDate();
      return d.isAfter(start) && d.isBefore(end);
    }).toList();
  }

  double _weekEarnings(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    double total = 0;
    for (final doc in docs) {
      final d = doc.data() as Map;
      final ts = d['completedAt'];
      if (ts is! Timestamp) continue;
      if (ts.toDate().isBefore(weekStart)) continue;
      final v = d['amount'];
      if (v != null) {
        total += (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
      }
    }
    return total;
  }

  void _onBottomNavTap(int index) {
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
  }

  Future<void> _toggleAvailability(bool current) async {
    await FirebaseFirestore.instance
        .collection('service_providers')
        .doc(_uid)
        .update({
      'isAvailable': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _acceptJob(String bookingId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      final status = (doc.data() as Map?)?['status']?.toString() ?? '';

      if (status == 'pending_provider_confirmation') {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': 'confirmed',
          'returnVisitConfirmedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west4')
            .httpsCallable('confirmBooking');
        await callable.call({'bookingId': bookingId});
      }
      if (mounted) context.push('/provider-job-detail', extra: bookingId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to confirm: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _declineJob(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'declined',
        'declineReason': 'Not available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _providerStream,
      builder: (context, provSnap) {
        final provider = provSnap.data?.data() as Map<String, dynamic>? ?? {};
        final displayName = provider['displayName'] as String? ??
            FirebaseAuth.instance.currentUser?.displayName ??
            'Provider';
        final isAvailable = provider['isAvailable'] as bool? ?? true;

        return StreamBuilder<QuerySnapshot>(
          stream: _pendingStream,
          builder: (context, pendingSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: _pendingQuotesStream,
              builder: (context, quotesSnap) {
                final pendingDocs = List<QueryDocumentSnapshot>.from(
                    pendingSnap.data?.docs ?? []);
                final pendingQuoteDocs = List<QueryDocumentSnapshot>.from(
                    quotesSnap.data?.docs ?? []);
                final allPendingCount =
                    pendingDocs.length + pendingQuoteDocs.length;

                return StreamBuilder<QuerySnapshot>(
                  stream: _activeStream,
                  builder: (context, activeSnap) {
                    final activeDocs = List<QueryDocumentSnapshot>.from(
                        activeSnap.data?.docs ?? []);
                    final weekDocs = _weekJobs(activeDocs).where((doc) {
                      final status =
                          (doc.data() as Map)['status']?.toString() ?? '';
                      return status == 'confirmed' || status == 'accepted';
                    }).toList()
                      ..sort((a, b) {
                        final aTs = ((a.data() as Map)['scheduledDate']);
                        final bTs = ((b.data() as Map)['scheduledDate']);
                        if (aTs is Timestamp && bTs is Timestamp)
                          return aTs.compareTo(bTs);
                        return 0;
                      });

                    return StreamBuilder<QuerySnapshot>(
                      stream: _earningsStream,
                      builder: (context, earningsSnap) {
                        final earningsDocs = List<QueryDocumentSnapshot>.from(
                            earningsSnap.data?.docs ?? []);
                        final weekTotal = _weekEarnings(earningsDocs);

                        return BannerNotificationOverlay(
                          child: Scaffold(
                            backgroundColor: Colors.white,
                            body: SafeArea(
                              child: Column(
                                children: [
                                  _buildTopBar(displayName, isAvailable),
                                  BankingDetailsBanner(
                                      route: '/provider-payout-settings'),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildHeroBanner(
                                              displayName, isAvailable),
                                          Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildStatsCards(
                                                  todayCount: weekDocs.length,
                                                  weekEarnings: weekTotal,
                                                  pendingCount: allPendingCount,
                                                ),
                                                const SizedBox(height: 24),
                                                _buildQuickActions(),
                                                const SizedBox(height: 24),
                                                _buildPendingSection(
                                                    pendingDocs,
                                                    pendingQuoteDocs),
                                                const SizedBox(height: 24),
                                                _buildTodayScheduleSection(
                                                    weekDocs),
                                                const SizedBox(height: 24),
                                                const OffersCarousel(
                                                    targetType: 'providers'),
                                                const SizedBox(height: 80),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 80),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            bottomNavigationBar: _buildBottomNav(),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(String displayName, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                child:
                    const Icon(Icons.person, size: 24, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back,',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleAvailability(isAvailable),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAvailable ? 'Online' : 'Offline',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => context.push('/provider-notifications'),
                icon: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .collection('notifications')
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined, size: 24),
                        if (count > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(String displayName, bool isAvailable) {
    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          ClipPath(
            clipper: HeroBannerClipper(),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.asset(
                    'assets/images/james-kovin-YQGPSblLPz0-unsplash.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, s) =>
                        Container(color: Colors.grey[800]),
                  ),
                  // Dark overlay (55% opacity)
                  const ColoredBox(color: Color(0x8C000000)),
                  // Subtle bottom gradient
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x4D000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x80000000), blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.pause_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAvailable ? 'Available' : 'Unavailable',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards({
    required int todayCount,
    required double weekEarnings,
    required int pendingCount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Today's Jobs",
                value: '$todayCount',
                icon: Icons.work_outline,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Week Earnings',
                value: 'R${weekEarnings.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Pending',
                value: '$pendingCount',
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Active Jobs',
                value: '$todayCount',
                icon: Icons.trending_up,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.add_circle_outline,
                label: 'Add Service',
                onTap: () => context.push('/provider-add-service'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.calendar_today,
                label: 'Availability',
                onTap: () => context.push('/provider-availability'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.history,
                label: 'Job History',
                onTap: () => context.push('/provider-job-history'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Colors.black),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSection(List<QueryDocumentSnapshot> pendingDocs,
      List<QueryDocumentSnapshot> pendingQuoteDocs) {
    if (pendingDocs.isEmpty && pendingQuoteDocs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                'Pending Requests (${pendingDocs.length + pendingQuoteDocs.length})',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            TextButton(
              onPressed: () => context.push('/provider-job-requests'),
              child: const Text('See All',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pendingDocs.take(2).map((doc) => _buildRequestCard(doc)),
        ...pendingQuoteDocs.take(2).map((doc) => _buildQuoteRequestCard(doc)),
      ],
    );
  }

  Widget _buildRequestCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final bookingId = doc.id;
    final clientName = d['clientName'] as String? ?? 'Unknown';
    final service = d['serviceCategory'] ?? d['service'] ?? 'Service';
    final scheduledTime = d['scheduledTime'] as String? ?? '—';
    final address = d['address'] ?? d['location'] ?? '—';
    final v = d['estimatedPrice'] ?? d['amount'];
    final amountStr = v != null
        ? 'R${((v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0).toStringAsFixed(0)}'
        : 'TBD';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                child:
                    const Icon(Icons.person, size: 20, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(service.toString(),
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(amountStr,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700])),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(scheduledTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 12),
              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(address.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineJob(bookingId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptJob(bookingId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Accept',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteRequestCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final clientName = d['clientName']?.toString() ?? 'Client';
    final category = d['category']?.toString() ?? 'Service';
    final address = d['address']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade200, width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Quote Request',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
        ]),
        const SizedBox(height: 8),
        Text(category,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(clientName,
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(address,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.push('/provider-quote-detail/${doc.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View & Quote',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _buildTodayScheduleSection(List<QueryDocumentSnapshot> todayDocs) {
    final visible = todayDocs.take(5).toList();
    final hasMore = todayDocs.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                "This Week's Schedule${todayDocs.isNotEmpty ? ' (${todayDocs.length})' : ''}",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            TextButton(
              onPressed: () => context.push('/provider-calendar'),
              child: const Text('View Calendar',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (todayDocs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_available,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No confirmed jobs this week',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          )
        else ...[
          ...visible.map((doc) => _buildScheduleCard(doc)),
          if (hasMore)
            GestureDetector(
              onTap: () => context.push('/provider-calendar'),
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'See all ${todayDocs.length} jobs this week',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildScheduleCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final service = d['serviceCategory'] ?? d['service'] ?? 'Service';
    final clientName = d['clientName'] as String? ?? '—';
    final address = d['address'] ?? d['location'] ?? '—';
    final scheduledTime = d['scheduledTime'] as String? ?? '—';
    final bookingId = doc.id;

    return GestureDetector(
      onTap: () => context.push('/provider-job-detail', extra: bookingId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule, size: 24, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.toString(),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '$clientName • ${address.toString()}',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(scheduledTime,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -4))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0x99FFFFFF),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HeroBannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    var fcp = Offset(size.width / 4, size.height - 10);
    var fep = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(fcp.dx, fcp.dy, fep.dx, fep.dy);
    var scp = Offset(size.width * 3 / 4, size.height - 50);
    var sep = Offset(size.width, size.height - 30);
    path.quadraticBezierTo(scp.dx, scp.dy, sep.dx, sep.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
