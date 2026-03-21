import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({Key? key}) : super(key: key);

  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> get _historyStream => FirebaseFirestore.instance
      .collection('bookings')
      .where('providerId', isEqualTo: _uid)
      .where('status',
          whereIn: ['completed', 'declined', 'cancelled'])
      .snapshots();

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return '—';
  }

  String _formatAmount(dynamic v) {
    if (v == null) return '—';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return 'R${n.toStringAsFixed(0)}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _historyStream,
      builder: (context, snap) {
        final docs =
            List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);

        // Sort by updatedAt descending
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['updatedAt'];
          final bTs = (b.data() as Map)['updatedAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        final completed =
            docs.where((d) => (d.data() as Map)['status'] == 'completed').toList();
        final cancelled = docs
            .where((d) =>
                (d.data() as Map)['status'] == 'declined' ||
                (d.data() as Map)['status'] == 'cancelled')
            .toList();

        // Compute total earnings from completed jobs
        double totalEarnings = 0;
        for (final doc in completed) {
          final d = doc.data() as Map;
          final v = d['estimatedPrice'] ?? d['amount'];
          if (v != null) {
            totalEarnings +=
                (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
          }
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.black),
            ),
            title: const Text('Job History',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildStatsSummary(completed.length, totalEarnings),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Colors.black))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(
                            docs: completed,
                            emptyTitle: 'No completed jobs',
                            emptySubtitle:
                                'Your completed jobs will appear here',
                            cardBuilder: _buildCompletedCard,
                          ),
                          _buildList(
                            docs: cancelled,
                            emptyTitle: 'No cancelled jobs',
                            emptySubtitle:
                                'Cancelled jobs will appear here',
                            cardBuilder: _buildCancelledCard,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSummary(int count, double totalEarnings) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Jobs', '$count', Icons.check_circle),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _buildStatItem('Earnings',
              'R${totalEarnings.toStringAsFixed(0)}', Icons.attach_money),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildList({
    required List<QueryDocumentSnapshot> docs,
    required String emptyTitle,
    required String emptySubtitle,
    required Widget Function(QueryDocumentSnapshot) cardBuilder,
  }) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(emptySubtitle,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: docs.length,
      itemBuilder: (context, i) => cardBuilder(docs[i]),
    );
  }

  Widget _buildCompletedCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final clientName = d['clientName'] as String? ?? '—';
    final service = d['serviceCategory'] ?? d['service'] ?? 'Service';
    final amount = _formatAmount(d['estimatedPrice'] ?? d['amount']);
    final dateStr = _formatDate(d['updatedAt'] ?? d['scheduledDate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.person,
                      size: 24, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(service.toString(),
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amount,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Completed',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final clientName = d['clientName'] as String? ?? '—';
    final service = d['serviceCategory'] ?? d['service'] ?? 'Service';
    final status = d['status'] as String? ?? 'cancelled';
    final reason =
        d['declineReason'] ?? d['cancelReason'] ?? d['cancellationReason'] ?? '—';
    final dateStr = _formatDate(d['updatedAt'] ?? d['scheduledDate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.person,
                      size: 24, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(service.toString(),
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'declined' ? 'Declined' : 'Cancelled',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.red[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Reason: $reason',
                      style: TextStyle(
                          fontSize: 13, color: Colors.red[400])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
