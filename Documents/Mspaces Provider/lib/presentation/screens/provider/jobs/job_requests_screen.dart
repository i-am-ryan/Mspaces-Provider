import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class JobRequestsScreen extends StatefulWidget {
  const JobRequestsScreen({Key? key}) : super(key: key);

  @override
  State<JobRequestsScreen> createState() => _JobRequestsScreenState();
}

class _JobRequestsScreenState extends State<JobRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> get _pendingStream => FirebaseFirestore.instance
      .collection('bookings')
      .where('providerId', isEqualTo: _uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Stream<QuerySnapshot> get _declinedStream => FirebaseFirestore.instance
      .collection('bookings')
      .where('providerId', isEqualTo: _uid)
      .where('status', isEqualTo: 'declined')
      .snapshots();

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

  Future<void> _acceptJob(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) context.push('/provider-job-detail', extra: bookingId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to accept job. Try again.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeclineDialog(String bookingId, String clientName) {
    String selectedReason = 'Schedule conflict';
    final reasons = [
      'Schedule conflict',
      'Too far away',
      'Service not offered',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Decline Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to decline the request from $clientName?',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              const Text('Select a reason:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...reasons.map((r) => InkWell(
                    onTap: () => setDlgState(() => selectedReason = r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == r
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: selectedReason == r
                                ? Colors.black
                                : Colors.grey[400],
                          ),
                          const SizedBox(width: 12),
                          Text(r),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance
                      .collection('bookings')
                      .doc(bookingId)
                      .update({
                    'status': 'declined',
                    'declineReason': selectedReason,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Request declined.'),
                          backgroundColor: Colors.orange),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Failed to decline. Try again.'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return ts.toString();
  }

  String _formatAmount(dynamic v) {
    if (v == null) return 'TBD';
    final n =
        (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return 'R${n.toStringAsFixed(0)}';
  }

  Color _urgencyColor(String? urgency) {
    switch (urgency) {
      case 'emergency':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _urgencyLabel(String? urgency) {
    switch (urgency) {
      case 'emergency':
        return 'EMERGENCY';
      case 'urgent':
        return 'URGENT';
      default:
        return 'NORMAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text('Job Requests',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          tabs: const [Tab(text: 'Pending'), Tab(text: 'Declined')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingTab(), _buildDeclinedTab()],
      ),
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) {
          return _buildError('Could not load job requests.');
        }

        final docs =
            List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'];
          final bTs = (b.data() as Map)['createdAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'New job requests will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildRequestCard(docs[i]),
        );
      },
    );
  }

  Widget _buildDeclinedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _declinedStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) {
          return _buildError('Could not load declined requests.');
        }

        final docs =
            List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['updatedAt'];
          final bTs = (b.data() as Map)['updatedAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.cancel_outlined,
            title: 'No declined requests',
            subtitle: 'Requests you decline will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildDeclinedCard(docs[i]),
        );
      },
    );
  }

  Widget _buildRequestCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final bookingId = doc.id;
    final clientName = d['clientName'] as String? ?? 'Unknown Client';
    final serviceCategory =
        d['serviceCategory'] ?? d['service'] ?? d['serviceType'] ?? 'Service';
    final address = d['address'] ?? d['location'] ?? '—';
    final scheduledTime = d['scheduledTime'] as String? ?? '—';
    final urgency = d['urgency'] as String?;
    final amount = _formatAmount(d['estimatedPrice'] ?? d['amount']);
    final dateStr = _formatDate(d['scheduledDate']);
    final description = d['serviceDescription'] ?? d['description'] ?? '';
    final isUrgent = urgency == 'urgent' || urgency == 'emergency';
    final urgencyColor = _urgencyColor(urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? urgencyColor : const Color(0x1A000000),
          width: isUrgent ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUrgent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.priority_high,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_urgencyLabel(urgency)} REQUEST',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          Padding(
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(serviceCategory.toString(),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(amount,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700])),
                    ),
                  ],
                ),
                if (description.toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(description.toString(),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[700])),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(Icons.calendar_today,
                        '$dateStr at $scheduledTime'),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                        Icons.location_on, address.toString()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _showDeclineDialog(bookingId, clientName),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Decline',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _acceptJob(bookingId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Accept & View',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclinedCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final clientName = d['clientName'] as String? ?? 'Unknown Client';
    final service =
        d['serviceCategory'] ?? d['service'] ?? 'Service';
    final reason = d['declineReason'] as String? ?? '—';
    final amount = _formatAmount(d['estimatedPrice'] ?? d['amount']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
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
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(service.toString(),
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Reason: $reason',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[400],
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Text(amount,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  decoration: TextDecoration.lineThrough)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
