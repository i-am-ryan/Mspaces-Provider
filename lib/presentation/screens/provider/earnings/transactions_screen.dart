// lib/presentation/screens/provider/earnings/transactions_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _entries = [];
  StreamSubscription<QuerySnapshot>? _invoicesSub;
  StreamSubscription<QuerySnapshot>? _entriesSub;

  final List<String> _filters = ['All', 'Outstanding', 'Paid'];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _invoicesSub?.cancel();
    _entriesSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    setState(() => _isLoading = true);

    _invoicesSub = FirebaseFirestore.instance
        .collection('invoices')
        .where('providerId', isEqualTo: _uid)
        .snapshots()
        .listen((snap) {
      _invoices = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList()
        ..sort((a, b) {
          final aTs = a['createdAt'] as Timestamp?;
          final bTs = b['createdAt'] as Timestamp?;
          if (aTs == null || bTs == null) return 0;
          return bTs.compareTo(aTs);
        });
      if (mounted) setState(() => _isLoading = false);
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });

    _entriesSub = FirebaseFirestore.instance
        .collection('transactions')
        .doc(_uid)
        .collection('entries')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _entries = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) setState(() {});
    });
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    switch (_selectedFilter) {
      case 'Outstanding':
        return _invoices
            .where((inv) =>
                inv['status'] == 'outstanding' || inv['status'] == 'unpaid')
            .toList();
      case 'Paid':
        return _invoices.where((inv) => inv['status'] == 'paid').toList();
      default:
        return _invoices;
    }
  }

  double _providerAmount(Map<String, dynamic> inv) =>
      (inv['providerAmount'] as num?)?.toDouble() ??
      (inv['subtotal'] as num?)?.toDouble() ??
      (inv['total'] as num?)?.toDouble() ??
      0;

  double get _totalIncome =>
      _invoices.fold(0, (sum, inv) => sum + _providerAmount(inv));

  double get _totalOutstanding => _invoices
      .where(
          (inv) => inv['status'] == 'outstanding' || inv['status'] == 'unpaid')
      .fold(0, (sum, inv) => sum + _providerAmount(inv));

  double get _totalPaid => _invoices
      .where((inv) => inv['status'] == 'paid')
      .fold(0, (sum, inv) => sum + _providerAmount(inv));

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
        title: const Text('Transactions',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _showExportOptions,
            icon: const Icon(Icons.download, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(children: [
              _buildSummarySection(),
              _buildFilterChips(),
              Expanded(
                child: _filteredInvoices.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, i) =>
                            _buildInvoiceCard(_filteredInvoices[i]),
                      ),
              ),
            ]),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildSummaryItem('Income', 'R ${_totalIncome.toStringAsFixed(0)}',
            Icons.arrow_downward, Colors.green),
        Container(height: 40, width: 1, color: Colors.grey[300]),
        _buildSummaryItem(
            'Outstanding',
            'R ${_totalOutstanding.toStringAsFixed(0)}',
            Icons.pending_outlined,
            Colors.orange),
        Container(height: 40, width: 1, color: Colors.grey[300]),
        _buildSummaryItem('Paid', 'R ${_totalPaid.toStringAsFixed(0)}',
            Icons.check_circle_outline, Colors.blue),
      ]),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            // Badge count
            int count = 0;
            if (filter == 'Outstanding') {
              count = _invoices
                  .where((inv) =>
                      inv['status'] == 'outstanding' ||
                      inv['status'] == 'unpaid')
                  .length;
            }
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedFilter = filter),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(filter,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black)),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$count',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected ? Colors.white : Colors.white)),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final invoiceId = inv['id']?.toString() ?? '';
    final invoiceNumber = inv['invoiceNumber']?.toString() ?? invoiceId;
    final clientName = inv['clientName']?.toString() ?? 'Client';
    final category = inv['serviceCategory']?.toString() ?? 'Service';
    final status = inv['status']?.toString() ?? 'outstanding';
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final outstanding =
        (inv['outstandingBalance'] as num?)?.toDouble() ?? total;
    final createdAt = (inv['createdAt'] as Timestamp?)?.toDate();
    final dueDate = (inv['dueDate'] as Timestamp?)?.toDate();
    final isPaid = status == 'paid';
    final isOverdue =
        dueDate != null && dueDate.isBefore(DateTime.now()) && !isPaid;
    final providerAmt = (inv['providerAmount'] as num?)?.toDouble() ??
        (inv['subtotal'] as num?)?.toDouble() ??
        total;

    Color statusColor = isPaid
        ? Colors.green
        : isOverdue
            ? Colors.red
            : Colors.orange;
    String statusLabel = isPaid
        ? 'Paid'
        : isOverdue
            ? 'Overdue'
            : 'Outstanding';

    return GestureDetector(
      onTap: () => context.push('/invoice-detail', extra: invoiceId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOverdue ? Colors.red.shade300 : const Color(0x1A000000),
            width: isOverdue ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle_outline : Icons.receipt_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(category,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  'R ${providerAmt.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                createdAt != null
                    ? DateFormat('dd MMM yyyy').format(createdAt)
                    : '—',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              if (dueDate != null && !isPaid) ...[
                const SizedBox(width: 10),
                Icon(Icons.alarm,
                    size: 12, color: isOverdue ? Colors.red : Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Due ${DateFormat('dd MMM').format(dueDate)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: isOverdue ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.w600),
                ),
              ],
              const Spacer(),
              Text(invoiceNumber,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontFamily: 'monospace')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Your invoices will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ]),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('Export Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildExportOption('Download PDF', Icons.picture_as_pdf, Colors.red,
              () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming soon')));
          }),
          _buildExportOption('Download CSV', Icons.table_chart, Colors.green,
              () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming soon')));
          }),
          _buildExportOption('Email Statement', Icons.email, Colors.blue, () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming soon')));
          }),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _buildExportOption(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
