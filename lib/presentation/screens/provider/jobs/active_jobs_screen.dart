// lib/presentation/screens/provider/jobs/active_jobs_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ActiveJobsScreen extends StatefulWidget {
  const ActiveJobsScreen({Key? key}) : super(key: key);

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> get _bookingsStream => FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _uid)
          .where('status', whereIn: [
        'accepted',
        'in_progress',
        'confirmed',
        'pending_provider_confirmation'
      ]).snapshots();

  Stream<QuerySnapshot> get _acceptedQuotesStream => FirebaseFirestore.instance
      .collection('quote_requests')
      .where('providerId', isEqualTo: _uid)
      .where('status', isEqualTo: 'accepted')
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

  String _formatDateTime(dynamic ts, [String? time]) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final dateStr = DateFormat('dd MMM').format(d);
      return time != null && time.isNotEmpty ? '$dateStr • $time' : dateStr;
    }
    if (ts is String) {
      final d = DateTime.tryParse(ts);
      if (d != null) {
        final dateStr = DateFormat('dd MMM · HH:mm').format(d);
        return dateStr;
      }
    }
    return time ?? '—';
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
        title: const Text('Active Jobs',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Bookings'),
            Tab(text: 'Accepted Quotes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsTab(),
          _buildAcceptedQuotesTab(),
        ],
      ),
    );
  }

  // ── Bookings tab ──────────────────────────────────────────────────────────

  Widget _buildBookingsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _bookingsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) {
          return _buildError('Could not load active jobs.');
        }

        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['scheduledDate'];
          final bTs = (b.data() as Map)['scheduledDate'];
          if (aTs == null || bTs == null) return 0;
          return (aTs as Timestamp).compareTo(bTs as Timestamp);
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.work_off_outlined,
            title: 'No active bookings',
            subtitle: 'Accepted bookings will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _buildBookingCard(ctx, docs[i]),
        );
      },
    );
  }

  // ── Accepted quotes tab ───────────────────────────────────────────────────

  Widget _buildAcceptedQuotesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _acceptedQuotesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) {
          return _buildError('Could not load accepted quotes.');
        }

        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['acceptedAt'];
          final bTs = (b.data() as Map)['acceptedAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.request_quote_outlined,
            title: 'No accepted quotes',
            subtitle: 'Quotes accepted by clients will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _buildAcceptedQuoteCard(ctx, docs[i]),
        );
      },
    );
  }

  // ── Booking card ──────────────────────────────────────────────────────────

  Widget _buildBookingCard(BuildContext context, QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final bookingId = doc.id;
    final clientName = d['clientName'] as String? ?? 'Unknown Client';
    final service = d['serviceCategory'] ?? d['service'] ?? 'Service';
    final status = d['status'] as String? ?? 'accepted';
    final scheduledTime = d['scheduledTime'] as String? ?? '';
    final address = d['address'] ?? d['location'] ?? '—';
    final clientPhone = d['clientPhone'] as String? ?? '';
    final isInProgress = status == 'in_progress';
    final statusColor = isInProgress ? Colors.green : Colors.orange;
    final statusText = isInProgress ? 'In Progress' : 'Accepted';
    final dateTimeStr = _formatDateTime(d['scheduledDate'], scheduledTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // Status banner
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isInProgress ? Icons.build : Icons.check_circle_outline,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(statusText.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[200],
                child:
                    const Icon(Icons.person, size: 24, color: Colors.black54),
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
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(dateTimeStr,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(address.toString(),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              if (clientPhone.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/provider-job-detail', extra: bookingId),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  final snap = await FirebaseFirestore.instance
                      .collection('conversations')
                      .where('bookingId', isEqualTo: bookingId)
                      .limit(1)
                      .get();
                  final activeDocs = snap.docs
                      .where((d) => (d.data() as Map)['active'] == true)
                      .toList();
                  if (activeDocs.isNotEmpty && context.mounted) {
                    context.push('/provider-chat-detail', extra: {
                      'conversationId': activeDocs.first.id,
                      'otherName': clientName,
                      'otherRole': 'client',
                    });
                  } else if (context.mounted) {
                    // Create conversation
                    final ref = await FirebaseFirestore.instance
                        .collection('conversations')
                        .add({
                      'bookingId': bookingId,
                      'clientId': d['clientId'] ?? d['userId'] ?? '',
                      'clientName': clientName,
                      'providerId': FirebaseAuth.instance.currentUser?.uid,
                      'providerName': d['providerName'] ?? '',
                      'serviceCategory': d['serviceCategory'] ?? '',
                      'active': true,
                      'lastMessage': '',
                      'lastMessageAt': FieldValue.serverTimestamp(),
                      'unreadClient': 0,
                      'unreadProvider': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) {
                      context.push('/provider-chat-detail', extra: {
                        'conversationId': ref.id,
                        'otherName': clientName,
                        'otherRole': 'client',
                      });
                    }
                  }
                },
                icon: const Icon(Icons.chat_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Accepted quote card ───────────────────────────────────────────────────

  Widget _buildAcceptedQuoteCard(
      BuildContext context, QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final clientName = d['clientName']?.toString() ?? 'Client';
    final category = d['category']?.toString() ?? 'Service';
    final address = d['address']?.toString() ?? '—';
    final scheduledDate = d['scheduledDate'];
    final acceptedAt = d['acceptedAt'];
    final quote = d['quote'] as Map<String, dynamic>?;
    final total = (quote?['total'] as num?)?.toDouble() ?? 0;
    final notes = quote?['notes']?.toString() ?? '';
    final lineItems = quote?['lineItems'] as List? ?? [];
    final dateStr = _formatDateTime(scheduledDate);
    final acceptedStr = _formatDateTime(acceptedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                size: 16, color: Colors.white),
            const SizedBox(width: 8),
            const Text('QUOTE ACCEPTED',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const Spacer(),
            if (acceptedStr.isNotEmpty)
              Text(acceptedStr,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Client + category
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.green.shade50,
                child: Text(
                  clientName[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(category,
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'R ${total.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Scheduled date
            if (dateStr.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Scheduled: $dateStr',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 10),
            ],

            // Address
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(address,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            // Quote breakdown
            if (lineItems.isNotEmpty) ...[
              const Text('Quote Breakdown',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    ...lineItems.asMap().entries.map((e) {
                      final item = e.value as Map<String, dynamic>;
                      final desc = item['description']?.toString() ?? '';
                      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
                      final isLast = e.key == lineItems.length - 1;
                      return Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Expanded(
                              child: Text(desc,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Text(
                              'R ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                        if (!isLast)
                          Divider(height: 1, color: Colors.grey.shade200),
                      ]);
                    }),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(9),
                          bottomRight: Radius.circular(9),
                        ),
                      ),
                      child: Row(children: [
                        const Expanded(
                          child: Text('Total',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Text('R ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Notes
            if (notes.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(notes,
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue.shade800)),
                      ),
                    ]),
              ),
              const SizedBox(height: 10),
            ],

            // Mark as complete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markAsComplete(context, doc.id, clientName),
                icon: const Icon(Icons.check_circle_outline,
                    size: 18, color: Colors.white),
                label: const Text('Mark as Complete',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Mark complete ─────────────────────────────────────────────────────────

  Future<void> _markAsComplete(
      BuildContext context, String quoteRequestId, String clientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Complete'),
        content: Text('Mark the job for $clientName as complete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('quote_requests')
          .doc(quoteRequestId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job for $clientName marked as complete!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ]),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey[600])),
      ]),
    );
  }
}
