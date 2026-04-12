// lib/presentation/screens/provider/jobs/job_requests_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  Stream<QuerySnapshot> get _activeBookingsStream => FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _uid)
          .where('status', whereIn: [
        'pending',
        'pending_provider_confirmation',
        'confirmed',
        'accepted',
        'in_progress',
        'assessment_complete',
      ]).snapshots();

  Stream<QuerySnapshot> get _allQuotesStream => FirebaseFirestore.instance
      .collection('quote_requests')
      .where('providerId', isEqualTo: _uid)
      .snapshots();

  Stream<QuerySnapshot> get _pastBookingsStream => FirebaseFirestore.instance
      .collection('bookings')
      .where('providerId', isEqualTo: _uid)
      .where('status',
          whereIn: ['completed', 'declined', 'cancelled']).snapshots();

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

  bool _isAccepting = false;

  Future<void> _acceptJob(String bookingId) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      // Check booking status first
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      final status = (doc.data() as Map?)?['status']?.toString() ?? '';

      if (status == 'pending_provider_confirmation') {
        // Return visit confirmation — just update status, no invoice
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': 'confirmed',
          'returnVisitConfirmedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Notify client
        final data = doc.data() as Map<String, dynamic>;
        final clientId =
            data['clientId']?.toString() ?? data['userId']?.toString() ?? '';
        if (clientId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(clientId)
              .collection('notifications')
              .add({
            'title': 'Return Visit Confirmed',
            'body': 'Your provider has confirmed the return visit date.',
            'type': 'return_visit_confirmed',
            'bookingId': bookingId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Initial booking confirmation — call CF which generates INV-COF
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west4')
            .httpsCallable('confirmBooking');
        await callable.call({'bookingId': bookingId});
      }

      if (mounted) context.push('/provider-job-detail', extra: bookingId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to confirm: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _showDeclineDialog(String bookingId, String clientName) {
    String selectedReason = 'Schedule conflict';
    final reasons = [
      'Schedule conflict',
      'Too far away',
      'Service not offered',
      'Other'
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Decline Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Decline the request from $clientName?',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              const Text('Select a reason:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...reasons.map((r) => InkWell(
                    onTap: () => setDlg(() => selectedReason = r),
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Request declined.'),
                        backgroundColor: Colors.orange));
                  }
                } catch (_) {}
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

  void _showQuoteSheet(String quoteRequestId, Map<String, dynamic> data) {
    final clientName = data['clientName']?.toString() ?? 'Client';
    final category = data['category']?.toString() ?? 'Service';
    final List<Map<String, TextEditingController>> lineItems = [
      {
        'desc': TextEditingController(text: category),
        'amount': TextEditingController()
      },
    ];
    final notesCtrl = TextEditingController();
    final validDaysCtrl = TextEditingController(text: '7');
    bool isSending = false;
    bool includeVat = false;
    bool requireDeposit = false;
    double depositPercent = 50;

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
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                ),
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
                // VAT + Deposit options
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Checkbox(
                        value: includeVat,
                        onChanged: (v) =>
                            setSheet(() => includeVat = v ?? false),
                        activeColor: Colors.black,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Include VAT (15%)',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                includeVat
                                    ? 'VAT will be added to the total'
                                    : 'Add 15% VAT to subtotal',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ]),
                      ),
                    ]),
                    Divider(height: 1, color: Colors.grey.shade200),
                    Row(children: [
                      Checkbox(
                        value: requireDeposit,
                        onChanged: (v) =>
                            setSheet(() => requireDeposit = v ?? false),
                        activeColor: Colors.black,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Require Deposit',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                requireDeposit
                                    ? '${depositPercent.toInt()}% payable upfront'
                                    : 'Request upfront deposit',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ]),
                      ),
                      if (requireDeposit)
                        DropdownButton<double>(
                          value: depositPercent,
                          isDense: true,
                          underline: const SizedBox(),
                          items: [25.0, 30.0, 50.0, 60.0, 70.0]
                              .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.toInt()}%',
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) =>
                              setSheet(() => depositPercent = v ?? 50),
                        ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Notes (Optional)',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Any additional notes or conditions',
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            final items = lineItems
                                .where((item) =>
                                    item['desc']!.text.trim().isNotEmpty &&
                                    item['amount']!.text.trim().isNotEmpty)
                                .toList();
                            if (items.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Add at least one line item with an amount'),
                                      backgroundColor: Colors.red));
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
                              final subtotal = lineItemData.fold<double>(
                                  0,
                                  (sum, item) =>
                                      sum + (item['amount'] as double));
                              final vatAmount =
                                  includeVat ? subtotal * 0.15 : 0;
                              final total = subtotal + vatAmount;
                              final depositAmount = requireDeposit
                                  ? total * depositPercent / 100
                                  : 0;
                              final callable = FirebaseFunctions.instanceFor(
                                      region: 'europe-west4')
                                  .httpsCallable('submitProviderQuote');
                              await callable.call({
                                'quoteRequestId': quoteRequestId,
                                'lineItems': lineItemData,
                                'subtotal': subtotal,
                                'vatAmount': vatAmount,
                                'includeVat': includeVat,
                                'total': total,
                                'requireDeposit': requireDeposit,
                                'depositPercent': depositPercent,
                                'depositAmount': depositAmount,
                                'notes': notesCtrl.text.trim(),
                                'validDays':
                                    int.tryParse(validDaysCtrl.text) ?? 7,
                              });
                              if (mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Quote sent to $clientName!'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ));
                              }
                            } catch (e) {
                              setSheet(() => isSending = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Failed to send quote: $e'),
                                        backgroundColor: Colors.red));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/provider-create-quote', extra: {
          'bookingId': '',
          'clientId': '',
          'clientName': '',
          'category': '',
          'address': '',
          'description': '',
          'providerId': _uid,
          'providerName': '',
        }),
        backgroundColor: Colors.black,
        icon: const Icon(Icons.request_quote_outlined, color: Colors.white),
        label:
            const Text('Create Quote', style: TextStyle(color: Colors.white)),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text('My Jobs',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Quotes'),
            Tab(text: 'Past')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActiveTab(), _buildQuotesTab(), _buildPastTab()],
      ),
    );
  }

  Widget _buildActiveTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _activeBookingsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) return _buildError('Could not load jobs.');
        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'];
          final bTs = (b.data() as Map)['createdAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });
        if (docs.isEmpty) {
          return _buildEmptyState(
              icon: Icons.work_outline,
              title: 'No active jobs',
              subtitle: 'New booking requests will appear here');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildActiveCard(docs[i]),
        );
      },
    );
  }

  Widget _buildQuotesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allQuotesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) return _buildError('Could not load quotes.');
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
              subtitle: 'Quote requests from clients will appear here');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildQuoteCard(docs[i]),
        );
      },
    );
  }

  Widget _buildPastTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _pastBookingsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (snap.hasError) return _buildError('Could not load past jobs.');
        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['updatedAt'];
          final bTs = (b.data() as Map)['updatedAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });
        if (docs.isEmpty) {
          return _buildEmptyState(
              icon: Icons.history,
              title: 'No past jobs',
              subtitle: 'Completed and declined jobs will appear here');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildPastCard(docs[i]),
        );
      },
    );
  }

  Widget _buildActiveCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final bookingId = doc.id;
    final clientName = d['clientName']?.toString() ?? 'Unknown Client';
    final category = d['serviceCategory']?.toString() ??
        d['category']?.toString() ??
        d['service']?.toString() ??
        'Service';
    final status = d['status']?.toString() ?? 'pending';
    final address = d['address']?.toString() ?? '—';
    final source = d['source']?.toString() ?? '';
    final total = (d['total'] as num?)?.toDouble() ??
        (d['estimatedPrice'] as num?)?.toDouble();
    final scheduledDate = d['scheduledDate'];
    final dateStr = _formatDate(scheduledDate);
    final description = d['description']?.toString() ??
        d['serviceDescription']?.toString() ??
        '';

    Color statusColor;
    String statusLabel;
    bool needsAction = false;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'New Request';
        needsAction = true;
        break;
      case 'pending_provider_confirmation':
        statusColor = Colors.blue;
        statusLabel = 'Needs Confirmation';
        needsAction = true;
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusLabel = 'Confirmed';
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusLabel = 'Accepted';
        break;
      case 'in_progress':
        statusColor = Colors.purple;
        statusLabel = 'In Progress';
        break;
      case 'assessment_complete':
        statusColor = Colors.teal;
        statusLabel = 'Assessment Done';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = status;
    }

    return GestureDetector(
      onTap: () => context.push('/provider-job-detail', extra: bookingId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: needsAction ? statusColor : const Color(0x1A000000),
              width: needsAction ? 2 : 1),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Column(children: [
          if (needsAction)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.notifications_active,
                    size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  status == 'pending_provider_confirmation'
                      ? 'ACTION REQUIRED — TAP TO CONFIRM'
                      : 'NEW REQUEST — TAP TO RESPOND',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[200],
                  child: Text(
                      clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clientName,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(category,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                  if (source == 'quote') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Text('From Quote',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ]),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                _infoChip(Icons.calendar_today_outlined, dateStr),
                const SizedBox(width: 8),
                _infoChip(Icons.location_on_outlined, address),
              ]),
              if (total != null) ...[
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600])),
                      Text('R ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
              ],
              if (needsAction) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _showDeclineDialog(bookingId, clientName),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('Decline',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          _isAccepting ? null : () => _acceptJob(bookingId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        status == 'pending_provider_confirmation'
                            ? 'Confirm Booking'
                            : 'Accept',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ],
              if (status == 'assessment_complete') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/provider-create-quote', extra: {
                      'bookingId': doc.id,
                      'clientId':
                          (d['clientId'] ?? d['userId'])?.toString() ?? '',
                      'clientName': d['clientName']?.toString() ?? 'Client',
                      'category': d['serviceCategory']?.toString() ??
                          d['category']?.toString() ??
                          'Service',
                      'address': d['address']?.toString() ?? '',
                      'description': d['description']?.toString() ?? '',
                      'providerId': d['providerId']?.toString() ?? '',
                      'providerName': d['providerName']?.toString() ?? '',
                    }),
                    icon: const Icon(Icons.request_quote_outlined,
                        size: 16, color: Colors.white),
                    label: const Text('Create Quote',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Tap to view details →',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
              ],
            ]),
          ),
          // Chat action bar
          if (status == 'confirmed' ||
              status == 'accepted' ||
              status == 'in_progress' ||
              status == 'assessment_complete')
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x1A000000)))),
              child: TextButton.icon(
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
                    final ref = await FirebaseFirestore.instance
                        .collection('conversations')
                        .add({
                      'bookingId': bookingId,
                      'clientId': d['clientId'] ?? d['userId'] ?? '',
                      'clientName': clientName,
                      'providerId': FirebaseAuth.instance.currentUser?.uid,
                      'providerName': d['providerName'] ?? '',
                      'serviceCategory': category,
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
                icon: const Icon(Icons.chat_bubble_outline,
                    size: 18, color: Colors.black),
                label: const Text('Message',
                    style: TextStyle(color: Colors.black)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildQuoteCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final quoteRequestId = doc.id;
    final clientName = d['clientName']?.toString() ?? 'Client';
    final category = d['category']?.toString() ?? 'Service';
    final status = d['status']?.toString() ?? 'pending';
    final createdAt = d['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy').format(createdAt.toDate())
        : '—';
    final quoteData = d['quote'] as Map<String, dynamic>?;
    final total = (quoteData?['total'] as num?)?.toDouble();
    final description = d['description']?.toString() ?? '';
    final address = d['address']?.toString() ?? '—';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    bool canQuote = false;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Awaiting Quote';
        statusIcon = Icons.hourglass_top;
        canQuote = true;
        break;
      case 'quoted':
        statusColor = Colors.blue;
        statusLabel = 'Quote Sent';
        statusIcon = Icons.send_outlined;
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusLabel = 'Accepted';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'declined':
      case 'provider_declined':
        statusColor = Colors.red;
        statusLabel = 'Declined';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Completed';
        statusIcon = Icons.task_alt;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = status;
        statusIcon = Icons.info_outline;
    }

    return GestureDetector(
      onTap: () => context.push('/provider-quote-detail/$quoteRequestId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  canQuote ? Colors.orange.shade300 : const Color(0x1A000000),
              width: canQuote ? 2 : 1),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor))),
              Text(dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[200],
                  child: Text(clientName[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
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
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ]),
                ),
                if (total != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('R ${total.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700)),
                  ),
              ]),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Row(children: [_infoChip(Icons.location_on_outlined, address)]),
              const SizedBox(height: 8),
              Text(quoteRequestId,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontFamily: 'monospace')),
              if (canQuote) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
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
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPastCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final clientName = d['clientName']?.toString() ?? 'Unknown Client';
    final category = d['serviceCategory']?.toString() ??
        d['category']?.toString() ??
        d['service']?.toString() ??
        'Service';
    final status = d['status']?.toString() ?? 'completed';
    final total = (d['total'] as num?)?.toDouble() ??
        (d['estimatedPrice'] as num?)?.toDouble();
    final updatedAt = d['updatedAt'] as Timestamp?;
    final dateStr = updatedAt != null
        ? DateFormat('dd MMM yyyy').format(updatedAt.toDate())
        : '—';
    final reason = d['declineReason']?.toString() ?? '';
    final isCompleted = status == 'completed';

    return GestureDetector(
      onTap: () => context.push('/provider-job-detail', extra: doc.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                isCompleted ? Colors.green.shade50 : Colors.red.shade50,
            child: Icon(
              isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isCompleted ? Colors.green : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(clientName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text(category,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              if (reason.isNotEmpty)
                Text('Reason: $reason',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[400],
                        fontStyle: FontStyle.italic)),
              Text(dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ]),
          ),
          if (total != null)
            Text('R ${total.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.green : Colors.grey[400],
                    decoration:
                        isCompleted ? null : TextDecoration.lineThrough)),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp)
      return DateFormat('dd MMM yyyy · HH:mm').format(ts.toDate());
    if (ts is String) {
      final d = DateTime.tryParse(ts);
      if (d != null) return DateFormat('dd MMM yyyy · HH:mm').format(d);
    }
    return ts.toString();
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
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
