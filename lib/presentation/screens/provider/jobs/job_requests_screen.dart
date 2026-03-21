// lib/presentation/screens/provider/jobs/job_requests_screen.dart

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
      .where('status',
          whereIn: ['pending', 'pending_provider_confirmation']).snapshots();

  Stream<QuerySnapshot> get _declinedStream => FirebaseFirestore.instance
      .collection('bookings')
      .where('providerId', isEqualTo: _uid)
      .where('status', isEqualTo: 'declined')
      .snapshots();

  Stream<QuerySnapshot> get _quoteRequestsStream => FirebaseFirestore.instance
      .collection('quote_requests')
      .where('providerId', isEqualTo: _uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Accept booking ────────────────────────────────────────────────────────

  Future<void> _acceptJob(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'confirmed',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify client
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      final clientId = bookingDoc.data()?['clientId']?.toString() ?? '';
      if (clientId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(clientId)
            .collection('notifications')
            .add({
          'title': 'Booking Confirmed!',
          'body':
              'Your booking has been confirmed by the provider. Please pay the call-out fee to proceed.',
          'type': 'booking_confirmed',
          'bookingId': bookingId,
          'read': false,
          'actionRequired': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
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

  // ── Decline booking dialog ────────────────────────────────────────────────

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
                      child: Row(children: [
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
                      ]),
                    ),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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

  // ── Send quote sheet ──────────────────────────────────────────────────────

  void _showQuoteSheet(String quoteRequestId, Map<String, dynamic> data) {
    final clientName = data['clientName']?.toString() ?? 'Client';
    final category = data['category']?.toString() ?? 'Service';

    // Line item controllers
    final List<Map<String, TextEditingController>> lineItems = [
      {
        'desc': TextEditingController(text: category),
        'amount': TextEditingController(),
      }
    ];
    final notesCtrl = TextEditingController();
    final validDaysCtrl = TextEditingController(text: '7');
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                ),

                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.request_quote_outlined,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Send Quote',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('To $clientName · $category',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ]),
                  ),
                ]),
                const SizedBox(height: 20),

                // Line items
                const Text('Line Items',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (ctx2, setItems) => Column(children: [
                    ...lineItems.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: item['desc'],
                              decoration: InputDecoration(
                                hintText: 'Description',
                                hintStyle: TextStyle(
                                    fontSize: 12, color: Colors.grey[400]),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: item['amount'],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                hintText: 'R 0.00',
                                hintStyle: TextStyle(
                                    fontSize: 12, color: Colors.grey[400]),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          if (lineItems.length > 1)
                            GestureDetector(
                              onTap: () =>
                                  setItems(() => lineItems.removeAt(i)),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(Icons.remove_circle,
                                    color: Colors.red[400], size: 18),
                              ),
                            ),
                        ]),
                      );
                    }),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setItems(() => lineItems.add({
                            'desc': TextEditingController(),
                            'amount': TextEditingController(),
                          })),
                      child: Row(children: [
                        Icon(Icons.add_circle_outline,
                            size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text('Add line item',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Notes
                const Text('Notes (Optional)',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Any additional notes, terms, or conditions for the client',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Valid for days
                Row(children: [
                  const Text('Quote valid for',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: validDaysCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('days',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ]),
                const SizedBox(height: 20),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            // Validate
                            final items = lineItems
                                .where((item) =>
                                    item['desc']!.text.trim().isNotEmpty &&
                                    item['amount']!.text.trim().isNotEmpty)
                                .toList();

                            if (items.isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Please add at least one line item with an amount'),
                                backgroundColor: Colors.red,
                              ));
                              return;
                            }

                            setSheet(() => isSending = true);

                            try {
                              final lineItemData = items
                                  .map((item) => {
                                        'description':
                                            item['desc']!.text.trim(),
                                        'amount': double.tryParse(
                                                item['amount']!.text.trim()) ??
                                            0,
                                      })
                                  .toList();

                              final total = lineItemData.fold<double>(
                                  0,
                                  (sum, item) =>
                                      sum + (item['amount'] as double));

                              final validDays =
                                  int.tryParse(validDaysCtrl.text) ?? 7;
                              final validUntil =
                                  DateTime.now().add(Duration(days: validDays));

                              await FirebaseFirestore.instance
                                  .collection('quote_requests')
                                  .doc(quoteRequestId)
                                  .update({
                                'status': 'quoted',
                                'quote': {
                                  'lineItems': lineItemData,
                                  'total': total,
                                  'notes': notesCtrl.text.trim(),
                                  'validUntil': Timestamp.fromDate(validUntil),
                                  'quotedAt': FieldValue.serverTimestamp(),
                                },
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              // Notify client
                              final clientId =
                                  data['clientId']?.toString() ?? '';
                              if (clientId.isNotEmpty) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(clientId)
                                    .collection('notifications')
                                    .add({
                                  'title': 'Quote Received',
                                  'body':
                                      'Your quote for $category is ready. Total: R${total.toStringAsFixed(0)}',
                                  'type': 'quote_received',
                                  'quoteRequestId': quoteRequestId,
                                  'read': false,
                                  'actionRequired': true,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                              }

                              if (mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Quote sent to $clientName!'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheet(() => isSending = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Failed to send quote: $e'),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Send Quote · R${lineItems.fold<double>(0, (sum, item) => sum + (double.tryParse(item['amount']!.text) ?? 0)).toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────────

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    if (ts is String) {
      final d = DateTime.tryParse(ts);
      if (d != null) return DateFormat('dd MMM yyyy').format(d);
    }
    return ts.toString();
  }

  String _formatAmount(dynamic v) {
    if (v == null) return 'TBD';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Bookings'),
            Tab(text: 'Quote Requests'),
            Tab(text: 'Declined'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildQuoteRequestsTab(),
          _buildDeclinedTab(),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) return _buildError('Could not load bookings.');

        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'];
          final bTs = (b.data() as Map)['createdAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending bookings',
            subtitle: 'New booking requests will appear here',
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

  Widget _buildQuoteRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _quoteRequestsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) {
          return _buildError('Could not load quote requests.');
        }

        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'];
          final bTs = (b.data() as Map)['createdAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.request_quote_outlined,
            title: 'No quote requests',
            subtitle: 'Quote requests from clients will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildQuoteRequestCard(docs[i]),
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

        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
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

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _buildQuoteRequestCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final quoteRequestId = doc.id;
    final clientName = d['clientName']?.toString() ?? 'Client';
    final category = d['category']?.toString() ?? 'Service';
    final description = d['description']?.toString() ?? '';
    final address = d['address']?.toString() ?? '—';
    final photos = d['photos'] as List? ?? [];
    final createdAt = d['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy').format(createdAt.toDate())
        : '—';
    final preferredDateFrom = d['preferredDateFrom']?.toString() ?? '';
    final preferredDateTo = d['preferredDateTo']?.toString() ?? '';

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.request_quote_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quote Request',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('Received $dateStr',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(category,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Client
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                child: Text(
                  clientName[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(category,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),

            // Description
            if (description.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.description_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text('Description',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 6),
                      Text(description,
                          style: const TextStyle(fontSize: 13, height: 1.4)),
                    ]),
              ),
              const SizedBox(height: 10),
            ],

            // Info chips
            Row(children: [
              _buildInfoChip(Icons.location_on_outlined, address),
              if (preferredDateFrom.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildInfoChip(
                    Icons.calendar_today_outlined,
                    preferredDateTo.isNotEmpty
                        ? '$preferredDateFrom – $preferredDateTo'
                        : preferredDateFrom),
              ],
            ]),

            // Photos
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 70,
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        photos[i].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('quote_requests')
                          .doc(quoteRequestId)
                          .update({
                        'status': 'provider_declined',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Quote request declined.'),
                              backgroundColor: Colors.orange),
                        );
                      }
                    } catch (_) {}
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _showQuoteSheet(quoteRequestId, d),
                  icon: const Icon(Icons.send_outlined,
                      size: 16, color: Colors.white),
                  label: const Text('Send Quote',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
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
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                const Icon(Icons.priority_high, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text('${_urgencyLabel(urgency)} REQUEST',
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
                      const SizedBox(height: 2),
                      Text(serviceCategory.toString(),
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            ]),
            if (d['source'] == 'quote') ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.request_quote_outlined,
                      size: 13, color: Colors.purple.shade700),
                  const SizedBox(width: 4),
                  Text('From Quote',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            if (description.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(description.toString(),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _buildInfoChip(
                  Icons.calendar_today, '$dateStr at $scheduledTime'),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.location_on, address.toString()),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showDeclineDialog(bookingId, clientName),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                      d['status'] == 'pending_provider_confirmation'
                          ? 'Confirm Booking'
                          : 'Accept & View',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDeclinedCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final clientName = d['clientName'] as String? ?? 'Unknown Client';
    final service = d['serviceCategory'] ?? d['service'] ?? 'Service';
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
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          child: const Icon(Icons.person, size: 24, color: Colors.black54),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(clientName,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(service.toString(),
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Reason: $reason',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[400],
                    fontStyle: FontStyle.italic)),
          ]),
        ),
        Text(amount,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                decoration: TextDecoration.lineThrough)),
      ]),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildInfoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }

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
