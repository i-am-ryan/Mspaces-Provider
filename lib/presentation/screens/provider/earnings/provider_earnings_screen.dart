// lib/presentation/screens/provider/earnings/provider_earnings_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'provider_invoice_detail_screen.dart';

class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({Key? key}) : super(key: key);
  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allInvoices = [];
  StreamSubscription<QuerySnapshot>? _invoicesSub;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoicesSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    setState(() => _isLoading = true);
    _invoicesSub = FirebaseFirestore.instance
        .collection('invoices')
        .where('providerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _allInvoices = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) setState(() => _isLoading = false);
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // Account balance = total earned - total paid out
  double get _accountBalance {
    double balance = 0;
    for (final inv in _allInvoices) {
      final type = inv['invoiceType']?.toString() ?? '';
      final status = inv['status']?.toString() ?? '';
      if (type == 'payout' && inv['payoutStatus'] == 'paid') {
        balance -= (inv['payoutAmount'] as num?)?.toDouble() ?? 0;
        balance -= (inv['commission'] as num?)?.toDouble() ?? 0;
        balance -= (inv['transactionFee'] as num?)?.toDouble() ?? 0;
      } else if (type != 'payout' && status == 'paid') {
        balance += _providerAmt(inv);
      }
    }
    return balance.clamp(0.0, double.infinity);
  }

  double get _totalEarned {
    return _allInvoices
        .where(
            (inv) => inv['invoiceType'] != 'payout' && inv['status'] == 'paid')
        .fold(0.0, (sum, inv) => sum + _providerAmt(inv));
  }

  double get _totalPaidOut {
    return _allInvoices
        .where((inv) =>
            inv['invoiceType'] == 'payout' && inv['payoutStatus'] == 'paid')
        .fold(
            0.0,
            (sum, inv) =>
                sum + ((inv['payoutAmount'] as num?)?.toDouble() ?? 0));
  }

  double get _pendingAmount {
    return _allInvoices
        .where((inv) =>
            inv['invoiceType'] != 'payout' &&
            (inv['status'] == 'outstanding' || inv['status'] == 'unpaid'))
        .fold(0.0, (sum, inv) => sum + _providerAmt(inv));
  }

  double _providerAmt(Map<String, dynamic> inv) =>
      (inv['providerAmount'] as num?)?.toDouble() ??
      (inv['subtotal'] as num?)?.toDouble() ??
      0;

  // Last payout date
  DateTime? get _lastPayoutDate {
    final payouts = _allInvoices
        .where((inv) =>
            inv['invoiceType'] == 'payout' && inv['payoutStatus'] == 'paid')
        .toList();
    if (payouts.isEmpty) return null;
    payouts.sort((a, b) {
      final aTs = (a['paidAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
      final bTs = (b['paidAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
      return bTs.compareTo(aTs);
    });
    return (payouts.first['paidAt'] as Timestamp?)?.toDate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text('Earnings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Statements'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                  accountBalance: _accountBalance,
                  totalEarned: _totalEarned,
                  totalPaidOut: _totalPaidOut,
                  pendingAmount: _pendingAmount,
                  lastPayoutDate: _lastPayoutDate,
                  allInvoices: _allInvoices,
                  uid: _uid,
                ),
                _StatementsTab(uid: _uid, allInvoices: _allInvoices),
              ],
            ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final double accountBalance;
  final double totalEarned;
  final double totalPaidOut;
  final double pendingAmount;
  final DateTime? lastPayoutDate;
  final List<Map<String, dynamic>> allInvoices;
  final String uid;

  const _OverviewTab({
    required this.accountBalance,
    required this.totalEarned,
    required this.totalPaidOut,
    required this.pendingAmount,
    required this.lastPayoutDate,
    required this.allInvoices,
    required this.uid,
  });

  void _showAllInvoices(
      BuildContext context, List<Map<String, dynamic>> invoices, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scroll) => Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: invoices.length,
              itemBuilder: (_, i) => _InvoiceTile(inv: invoices[i]),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentInvoices =
        allInvoices.where((inv) => inv['invoiceType'] != 'payout').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Account Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
            ),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Account Balance',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 8),
            Text('R ${accountBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: [
              _BalanceStat('Total Earned',
                  'R ${totalEarned.toStringAsFixed(2)}', Colors.green.shade300),
              _BalanceStat('Paid Out', 'R ${totalPaidOut.toStringAsFixed(2)}',
                  Colors.blue.shade300),
              _BalanceStat('Pending', 'R ${pendingAmount.toStringAsFixed(2)}',
                  Colors.amber.shade300),
            ]),
            if (lastPayoutDate != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last payout: ${DateFormat('dd MMM yyyy').format(lastPayoutDate!)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        // Request Payout Button
        if (accountBalance >= 200)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRequestPayoutSheet(context),
              icon: const Icon(Icons.payments_outlined, color: Colors.black),
              label: Text(
                  'Request Payout — R ${accountBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (accountBalance >= 200) const SizedBox(height: 24),

        // Recent Invoices
        // Recent Transactions (last 3)
        _SectionHeader(
          title: 'Recent Transactions',
          onSeeAll: recentInvoices.isEmpty
              ? null
              : () =>
                  _showAllInvoices(context, recentInvoices, 'All Transactions'),
        ),
        const SizedBox(height: 12),
        if (recentInvoices.isEmpty)
          _EmptySection('No transactions yet')
        else
          ...recentInvoices.take(3).map((inv) => _InvoiceTile(inv: inv)),
        const SizedBox(height: 24),

        // Payout Invoices (last 3)
        Builder(builder: (context) {
          final payouts = allInvoices
              .where((inv) => inv['invoiceType'] == 'payout')
              .toList();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Payout Invoices',
                  onSeeAll: payouts.isEmpty
                      ? null
                      : () =>
                          _showAllInvoices(context, payouts, 'Payout Invoices'),
                ),
                const SizedBox(height: 12),
                if (payouts.isEmpty)
                  _EmptySection('No payout invoices yet')
                else
                  ...payouts.take(3).map((inv) => _InvoiceTile(inv: inv)),
              ]);
        }),
        const SizedBox(height: 24),

        // Outstanding Receivables (last 3)
        Builder(builder: (context) {
          final outstanding = allInvoices
              .where((inv) =>
                  inv['invoiceType'] != 'payout' &&
                  (inv['status'] == 'outstanding' || inv['status'] == 'unpaid'))
              .toList();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Outstanding Receivables',
                  onSeeAll: outstanding.isEmpty
                      ? null
                      : () => _showAllInvoices(
                          context, outstanding, 'Outstanding Receivables'),
                ),
                const SizedBox(height: 12),
                if (outstanding.isEmpty)
                  _EmptySection('No outstanding receivables')
                else
                  ...outstanding.take(3).map((inv) => _InvoiceTile(inv: inv)),
              ]);
        }),
      ]),
    );
  }

  void _showRequestPayoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Request Payout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Your payout request will be reviewed and processed within 1-2 business days.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Gross Balance'),
                Text('R ${accountBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Commission (2%)',
                    style: TextStyle(color: Colors.grey)),
                Text('− R ${(accountBalance * 0.02).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Transaction fee (1.5%)',
                    style: TextStyle(color: Colors.grey)),
                Text('− R ${(accountBalance * 0.015).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey)),
              ]),
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('You will receive',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('R ${(accountBalance * 0.965).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green.shade700)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Save payout request to Firestore
                await FirebaseFirestore.instance
                    .collection('payout_requests')
                    .add({
                  'providerId': uid,
                  'grossAmount': accountBalance,
                  'commission': accountBalance * 0.02,
                  'transactionFee': accountBalance * 0.015,
                  'netAmount': accountBalance * 0.965,
                  'status': 'pending',
                  'requestedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Payout request submitted! We\'ll process it within 1-2 business days.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Payout Request',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BalanceStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      if (onSeeAll != null)
        GestureDetector(
          onTap: onSeeAll,
          child: Text('See All',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  decoration: TextDecoration.underline)),
        ),
    ]);
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
          child: Text(message, style: const TextStyle(color: Colors.grey))),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Map<String, dynamic> inv;
  const _InvoiceTile({required this.inv});

  @override
  Widget build(BuildContext context) {
    final type = inv['invoiceType']?.toString() ?? '';
    final status = inv['status']?.toString() ?? '';
    final isPaid = status == 'paid';
    final invoiceNumber = inv['invoiceNumber']?.toString() ?? '—';
    final createdAt = (inv['createdAt'] as Timestamp?)?.toDate();
    final amount = (inv['providerAmount'] as num?)?.toDouble() ??
        (inv['subtotal'] as num?)?.toDouble() ??
        0;

    Color typeColor;
    IconData typeIcon;
    switch (type) {
      case 'callout_fee':
        typeColor = Colors.orange;
        typeIcon = Icons.call_outlined;
        break;
      case 'deposit':
        typeColor = Colors.blue;
        typeIcon = Icons.savings_outlined;
        break;
      case 'job_completion':
        typeColor = Colors.green;
        typeIcon = Icons.check_circle_outline;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.receipt_outlined;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderInvoiceDetailScreen(invoiceId: inv['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invoiceNumber,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace')),
              if (createdAt != null)
                Text(DateFormat('dd MMM yyyy').format(createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('R ${amount.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPaid ? 'Paid' : 'Outstanding',
                style: TextStyle(
                    fontSize: 10,
                    color: isPaid ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Statements Tab ────────────────────────────────────────────────────────────

class _StatementsTab extends StatefulWidget {
  final String uid;
  final List<Map<String, dynamic>> allInvoices;
  const _StatementsTab({required this.uid, required this.allInvoices});

  @override
  State<_StatementsTab> createState() => _StatementsTabState();
}

class _StatementsTabState extends State<_StatementsTab> {
  DateTime _statementMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final monthStart = _statementMonth;
    final monthEnd =
        DateTime(_statementMonth.year, _statementMonth.month + 1, 1);

    // Opening balance (all before this month)
    double openingBalance = 0;
    for (final inv in widget.allInvoices) {
      final ts = inv['createdAt'] as Timestamp?;
      if (ts == null || !ts.toDate().isBefore(monthStart)) continue;
      final type = inv['invoiceType']?.toString() ?? '';
      final status = inv['status']?.toString() ?? '';
      if (type == 'payout' && inv['payoutStatus'] == 'paid') {
        openingBalance -= (inv['payoutAmount'] as num?)?.toDouble() ?? 0;
        openingBalance -= (inv['commission'] as num?)?.toDouble() ?? 0;
        openingBalance -= (inv['transactionFee'] as num?)?.toDouble() ?? 0;
      } else if (type != 'payout' && status == 'paid') {
        openingBalance += _providerAmt(inv);
      }
    }

    // This month transactions
    final monthInvoices = widget.allInvoices.where((inv) {
      final ts = inv['createdAt'] as Timestamp?;
      if (ts == null) return false;
      final date = ts.toDate();
      return date.isAfter(monthStart) && date.isBefore(monthEnd);
    }).toList();

    final lines = <Map<String, dynamic>>[];
    for (final inv in monthInvoices) {
      final type = inv['invoiceType']?.toString() ?? '';
      final status = inv['status']?.toString() ?? '';
      final date = (inv['createdAt'] as Timestamp?)?.toDate();

      if (type == 'payout' && inv['payoutStatus'] == 'paid') {
        final payoutAmount = (inv['payoutAmount'] as num?)?.toDouble() ?? 0;
        final commission = (inv['commission'] as num?)?.toDouble() ?? 0;
        final txFee = (inv['transactionFee'] as num?)?.toDouble() ?? 0;
        lines.add({
          'date': date,
          'description': 'Payout — ${inv['invoiceNumber'] ?? ''}',
          'amount': -payoutAmount,
          'type': 'payout',
        });
        lines.add({
          'date': date,
          'description': 'Commission (2%)',
          'amount': -commission,
          'type': 'fee',
        });
        lines.add({
          'date': date,
          'description': 'Transaction fee (1.5%)',
          'amount': -txFee,
          'type': 'fee',
        });
      } else if (type != 'payout' && status == 'paid') {
        final amount = _providerAmt(inv);
        if (amount > 0) {
          lines.add({
            'date': date,
            'description':
                '${_typeLabel(type)} — ${inv['invoiceNumber'] ?? ''}',
            'amount': amount,
            'type': 'income',
          });
        }
      }
    }

    lines.sort((a, b) {
      final aDate = a['date'] as DateTime?;
      final bDate = b['date'] as DateTime?;
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });

    double closingBalance = openingBalance;
    for (final line in lines) {
      closingBalance += (line['amount'] as double);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Month selector
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Statement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: () => _pickMonth(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMMM yyyy').format(_statementMonth),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            _StatSummary('Opening Balance',
                'R ${openingBalance.toStringAsFixed(2)}', Colors.white),
            _StatSummary(
                'Closing Balance',
                'R ${closingBalance.toStringAsFixed(2)}',
                Colors.green.shade300),
          ]),
        ),
        const SizedBox(height: 16),

        // Statement table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(children: [
                Expanded(
                    flex: 2,
                    child: Text('Date',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600]))),
                Expanded(
                    flex: 4,
                    child: Text('Description',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600]))),
                Expanded(
                    flex: 2,
                    child: Text('Amount',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600]),
                        textAlign: TextAlign.right)),
              ]),
            ),

            _StatRow(
              date: '01 ${DateFormat('MMM').format(_statementMonth)}',
              description: 'Opening Balance',
              amount: openingBalance,
              isBalance: true,
            ),

            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text('No transactions this month',
                        style: TextStyle(color: Colors.grey))),
              ),

            ...lines.map((line) => _StatRow(
                  date: line['date'] != null
                      ? DateFormat('dd MMM').format(line['date'] as DateTime)
                      : '—',
                  description: line['description'] as String,
                  amount: line['amount'] as double,
                  type: line['type'] as String,
                )),

            _StatRow(
              date: DateFormat('dd MMM').format(
                  DateTime(_statementMonth.year, _statementMonth.month + 1, 0)),
              description: 'Closing Balance',
              amount: closingBalance,
              isBalance: true,
              isClosing: true,
            ),
          ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  double _providerAmt(Map<String, dynamic> inv) =>
      (inv['providerAmount'] as num?)?.toDouble() ??
      (inv['subtotal'] as num?)?.toDouble() ??
      0;

  String _typeLabel(String type) {
    switch (type) {
      case 'callout_fee':
        return 'Call-out Fee';
      case 'deposit':
        return 'Deposit';
      case 'job_completion':
        return 'Job Completion';
      default:
        return type;
    }
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _statementMonth.year;
    int selectedMonth = _statementMonth.month;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Month'),
        content: StatefulBuilder(
          builder: (ctx, setDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setDialog(() => selectedYear--),
                  ),
                  Text('$selectedYear',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: selectedYear < now.year
                        ? () => setDialog(() => selectedYear++)
                        : null,
                  ),
                ],
              ),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 2,
                children: List.generate(12, (i) {
                  final month = i + 1;
                  final isSelected = month == selectedMonth;
                  final isFuture =
                      selectedYear == now.year && month > now.month;
                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () => setDialog(() => selectedMonth = month),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM').format(DateTime(2000, month)),
                          style: TextStyle(
                              fontSize: 12,
                              color: isFuture
                                  ? Colors.grey[300]
                                  : isSelected
                                      ? Colors.white
                                      : Colors.black),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() =>
                  _statementMonth = DateTime(selectedYear, selectedMonth, 1));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }
}

// ── Statement Row ─────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String date;
  final String description;
  final double amount;
  final String type;
  final bool isBalance;
  final bool isClosing;

  const _StatRow({
    required this.date,
    required this.description,
    required this.amount,
    this.type = 'income',
    this.isBalance = false,
    this.isClosing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = amount < 0;
    Color color;
    if (isClosing) {
      color = Colors.white;
    } else if (isBalance) {
      color = Colors.black;
    } else if (isNegative) {
      color = Colors.red.shade700;
    } else {
      color = Colors.green.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isClosing
            ? Colors.black
            : isBalance
                ? Colors.grey.shade50
                : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Text(date,
              style: TextStyle(
                  fontSize: 11,
                  color: isClosing ? Colors.white54 : Colors.grey[500])),
        ),
        Expanded(
          flex: 4,
          child: Text(description,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBalance ? FontWeight.bold : FontWeight.normal,
                  color: isClosing ? Colors.white : Colors.black),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${isNegative ? '−' : '+'} R ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: isBalance ? FontWeight.bold : FontWeight.w500,
                color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    );
  }
}

class _StatSummary extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatSummary(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
