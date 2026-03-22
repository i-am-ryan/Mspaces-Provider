// lib/presentation/screens/provider/earnings/provider_earnings_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({Key? key}) : super(key: key);

  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  String _selectedPeriod = 'This Month';
  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'All Time'
  ];

  bool _isLoading = true;
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _allInvoices = [];
  StreamSubscription<QuerySnapshot>? _entriesSub;
  StreamSubscription<QuerySnapshot>? _invoicesSub;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    _invoicesSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    setState(() => _isLoading = true);

    _entriesSub = FirebaseFirestore.instance
        .collection('transactions')
        .doc(_uid)
        .collection('entries')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _allEntries = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) setState(() => _isLoading = false);
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });

    _invoicesSub = FirebaseFirestore.instance
        .collection('invoices')
        .where('providerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _allInvoices = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) setState(() {});
    });
  }

  DateTime _periodStart() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      default:
        return DateTime(2020);
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    final start = _periodStart();
    return _allEntries.where((e) {
      final ts = e['createdAt'] as Timestamp?;
      if (ts == null) return false;
      return ts.toDate().isAfter(start);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    final start = _periodStart();
    return _allInvoices.where((inv) {
      final ts = inv['createdAt'] as Timestamp?;
      if (ts == null) return false;
      return ts.toDate().isAfter(start);
    }).toList();
  }

  double get _totalEarnings => _filteredEntries.fold(
      0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));

  double _providerAmt(Map<String, dynamic> inv) =>
      (inv['providerAmount'] as num?)?.toDouble() ??
      (inv['subtotal'] as num?)?.toDouble() ??
      (inv['total'] as num?)?.toDouble() ??
      0;

  double get _pendingAmount => _filteredInvoices
      .where(
          (inv) => inv['status'] == 'outstanding' || inv['status'] == 'unpaid')
      .fold(0, (sum, inv) => sum + _providerAmt(inv));

  double get _paidAmount => _filteredInvoices
      .where((inv) => inv['status'] == 'paid')
      .fold(0, (sum, inv) => sum + _providerAmt(inv));

  int get _completedJobs =>
      _filteredInvoices
          .where(
              (inv) => inv['status'] == 'paid' || inv['status'] == 'completed')
          .length +
      _filteredInvoices
          .where((inv) =>
              inv['status'] == 'outstanding' || inv['status'] == 'unpaid')
          .length;

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
        title: const Text('Earnings',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => context.push('/provider-transactions'),
            icon: const Icon(Icons.receipt_long, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  _buildTotalCard(),
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildBalanceCard(),
                  const SizedBox(height: 24),
                  _buildInvoicesSection(),
                  const SizedBox(height: 24),
                  _buildRecentEarnings(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _periods.map((period) {
            final isSelected = _selectedPeriod == period;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedPeriod = period),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(period,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, Color(0xFF333333)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      child: Column(children: [
        const Text('Total Earnings',
            style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Text(
          'R ${_totalEarnings.toStringAsFixed(0)}',
          style: const TextStyle(
              fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(_selectedPeriod,
            style: const TextStyle(fontSize: 13, color: Colors.white60)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildStat('Jobs', '$_completedJobs', Icons.work_outline),
          Container(height: 40, width: 1, color: Colors.white24),
          _buildStat('Outstanding', 'R ${_pendingAmount.toStringAsFixed(0)}',
              Icons.pending_outlined),
          Container(height: 40, width: 1, color: Colors.white24),
          _buildStat('Paid', 'R ${_paidAmount.toStringAsFixed(0)}',
              Icons.check_circle_outline),
        ]),
      ]),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(children: [
      Icon(icon, size: 20, color: Colors.white70),
      const SizedBox(height: 8),
      Text(value,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
    ]);
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
            child: _actionButton('Withdraw', Icons.account_balance_wallet,
                Colors.green, () => context.push('/provider-payout-settings'))),
        const SizedBox(width: 12),
        Expanded(
            child: _actionButton('History', Icons.history, Colors.blue,
                () => context.push('/provider-transactions'))),
        const SizedBox(width: 12),
        Expanded(
            child: _actionButton('Invoices', Icons.receipt_long, Colors.orange,
                () => _tabController())),
      ]),
    );
  }

  void _tabController() {
    // Scroll to invoices section
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Scroll down to see invoices'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final outstanding = _allInvoices
        .where((inv) =>
            inv['status'] == 'outstanding' || inv['status'] == 'unpaid')
        .fold<double>(0, (sum, inv) => sum + _providerAmt(inv));
    final allTimePaid = _allInvoices
        .where((inv) => inv['status'] == 'paid')
        .fold<double>(0, (sum, inv) => sum + _providerAmt(inv));
    final thisWeekEarnings = _allInvoices.where((inv) {
      final ts = inv['createdAt'] as Timestamp?;
      if (ts == null) return false;
      final weekStart =
          DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      return ts.toDate().isAfter(weekStart);
    }).fold<double>(0, (sum, inv) => sum + _providerAmt(inv));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Outstanding Receivables',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('R ${outstanding.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
          ElevatedButton(
            onPressed: () => context.push('/provider-transactions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('View All',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _balanceItem(
              'Pending', 'R ${outstanding.toStringAsFixed(0)}', Colors.orange),
          Container(height: 30, width: 1, color: Colors.grey[200]),
          _balanceItem(
              'Paid (All)', 'R ${allTimePaid.toStringAsFixed(0)}', Colors.blue),
          Container(height: 30, width: 1, color: Colors.grey[200]),
          _balanceItem('This Week', 'R ${thisWeekEarnings.toStringAsFixed(0)}',
              Colors.green),
        ]),
      ]),
    );
  }

  Widget _balanceItem(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _buildInvoicesSection() {
    if (_filteredInvoices.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Invoices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => context.push('/provider-transactions'),
            child: const Text('See All', style: TextStyle(color: Colors.black)),
          ),
        ]),
      ),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filteredInvoices.take(5).length,
        itemBuilder: (context, i) => _buildInvoiceCard(_filteredInvoices[i]),
      ),
    ]);
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final invoiceNumber = inv['invoiceNumber']?.toString() ?? '';
    final clientName = inv['clientName']?.toString() ?? 'Client';
    final category = inv['serviceCategory']?.toString() ?? 'Service';
    final status = inv['status']?.toString() ?? 'outstanding';
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final outstanding =
        (inv['outstandingBalance'] as num?)?.toDouble() ?? total;
    final createdAt = (inv['createdAt'] as Timestamp?)?.toDate();
    final isPaid = status == 'paid';

    return GestureDetector(
      onTap: () => context.push('/invoice-detail', extra: inv['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1A000000)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_outline : Icons.receipt_outlined,
              color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
              size: 20,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (createdAt != null)
                Text(DateFormat('dd MMM yyyy').format(createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('R ${_providerAmt(inv).toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isPaid ? 'Paid' : 'Outstanding',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPaid
                          ? Colors.green.shade700
                          : Colors.orange.shade700)),
            ),
            if (invoiceNumber.isNotEmpty)
              Text(invoiceNumber,
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[400],
                      fontFamily: 'monospace')),
          ]),
        ]),
      ),
    );
  }

  Widget _buildRecentEarnings() {
    final recent = _filteredEntries.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Recent Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => context.push('/provider-transactions'),
            child: const Text('See All', style: TextStyle(color: Colors.black)),
          ),
        ]),
      ),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recent.length,
        itemBuilder: (context, i) => _buildTransactionItem(recent[i]),
      ),
    ]);
  }

  Widget _buildTransactionItem(Map<String, dynamic> entry) {
    final clientName = entry['clientName']?.toString() ?? 'Client';
    final category = entry['serviceCategory']?.toString() ?? 'Service';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final status = entry['status']?.toString() ?? 'pending';
    final createdAt = (entry['createdAt'] as Timestamp?)?.toDate();
    final isPending = status != 'completed';

    String dateStr = '—';
    if (createdAt != null) {
      final now = DateTime.now();
      final diff = now.difference(createdAt);
      if (diff.inDays == 0)
        dateStr = 'Today, ${DateFormat('HH:mm').format(createdAt)}';
      else if (diff.inDays == 1)
        dateStr = 'Yesterday';
      else
        dateStr = DateFormat('dd MMM').format(createdAt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isPending ? Colors.orange[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPending ? Icons.pending : Icons.check_circle,
            color: isPending ? Colors.orange : Colors.green,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('$clientName · $dateStr',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('R ${amount.toStringAsFixed(0)}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPending ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPending ? 'Pending' : 'Paid',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isPending ? Colors.orange[700] : Colors.green[700]),
            ),
          ),
        ]),
      ]),
    );
  }
}
