import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Earnings', 'Withdrawals', 'Fees'];

  final List<Map<String, dynamic>> _allTransactions = const [
    {
      'id': '1',
      'type': 'earning',
      'description': 'Pipe Repair - Sarah Johnson',
      'amount': '+R765',
      'date': '16 Jan 2025',
      'time': '09:30 AM',
      'status': 'completed',
      'reference': 'TXN-2025-001234',
    },
    {
      'id': '2',
      'type': 'fee',
      'description': 'Platform Fee - Pipe Repair',
      'amount': '-R85',
      'date': '16 Jan 2025',
      'time': '09:30 AM',
      'status': 'completed',
      'reference': 'FEE-2025-001234',
    },
    {
      'id': '3',
      'type': 'withdrawal',
      'description': 'Bank Transfer - FNB ****4567',
      'amount': '-R5,000',
      'date': '15 Jan 2025',
      'time': '02:15 PM',
      'status': 'completed',
      'reference': 'WTH-2025-000892',
    },
    {
      'id': '4',
      'type': 'earning',
      'description': 'Drain Cleaning - Michael Chen',
      'amount': '+R585',
      'date': '15 Jan 2025',
      'time': '04:00 PM',
      'status': 'completed',
      'reference': 'TXN-2025-001233',
    },
    {
      'id': '5',
      'type': 'fee',
      'description': 'Platform Fee - Drain Cleaning',
      'amount': '-R65',
      'date': '15 Jan 2025',
      'time': '04:00 PM',
      'status': 'completed',
      'reference': 'FEE-2025-001233',
    },
    {
      'id': '6',
      'type': 'earning',
      'description': 'Water Heater Installation - Emily Brown',
      'amount': '+R2,250',
      'date': '14 Jan 2025',
      'time': '11:45 AM',
      'status': 'completed',
      'reference': 'TXN-2025-001232',
    },
    {
      'id': '7',
      'type': 'earning',
      'description': 'Toilet Repair - David Williams',
      'amount': '+R405',
      'date': '13 Jan 2025',
      'time': '03:30 PM',
      'status': 'pending',
      'reference': 'TXN-2025-001231',
    },
    {
      'id': '8',
      'type': 'withdrawal',
      'description': 'Bank Transfer - FNB ****4567',
      'amount': '-R3,500',
      'date': '10 Jan 2025',
      'time': '10:00 AM',
      'status': 'completed',
      'reference': 'WTH-2025-000891',
    },
  ];

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

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'All') return _allTransactions;
    return _allTransactions.where((t) {
      switch (_selectedFilter) {
        case 'Earnings':
          return t['type'] == 'earning';
        case 'Withdrawals':
          return t['type'] == 'withdrawal';
        case 'Fees':
          return t['type'] == 'fee';
        default:
          return true;
      }
    }).toList();
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
        title: const Text(
          'Transactions',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showExportOptions(),
            icon: const Icon(Icons.download, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummarySection(),

          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedFilter = filter),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Transactions list
          Expanded(
            child: _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionItem(_filteredTransactions[index]);
                    },
                  ),
          ),
        ],
      ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Income',
            'R12,450',
            Icons.arrow_downward,
            Colors.green,
          ),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _buildSummaryItem(
            'Withdrawn',
            'R8,500',
            Icons.arrow_upward,
            Colors.red,
          ),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _buildSummaryItem(
            'Fees',
            'R450',
            Icons.remove,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transactions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (transaction['type']) {
      case 'earning':
        icon = Icons.add_circle;
        iconColor = Colors.green;
        bgColor = Colors.green[50]!;
        break;
      case 'withdrawal':
        icon = Icons.account_balance;
        iconColor = Colors.blue;
        bgColor = Colors.blue[50]!;
        break;
      case 'fee':
        icon = Icons.remove_circle;
        iconColor = Colors.orange;
        bgColor = Colors.orange[50]!;
        break;
      default:
        icon = Icons.receipt;
        iconColor = Colors.grey;
        bgColor = Colors.grey[100]!;
    }

    final isPending = transaction['status'] == 'pending';
    final isPositive = transaction['amount'].toString().startsWith('+');

    return InkWell(
      onTap: () => _showTransactionDetail(transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A000000)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction['date']} • ${transaction['time']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  transaction['amount'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Transaction Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Description', transaction['description']),
            _buildDetailRow('Amount', transaction['amount']),
            _buildDetailRow('Date', transaction['date']),
            _buildDetailRow('Time', transaction['time']),
            _buildDetailRow('Reference', transaction['reference']),
            _buildDetailRow(
              'Status',
              transaction['status'] == 'completed' ? 'Completed' : 'Pending',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Export Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildExportOption(
              'Download PDF',
              Icons.picture_as_pdf,
              Colors.red,
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF exported successfully')),
                );
              },
            ),
            _buildExportOption(
              'Download CSV',
              Icons.table_chart,
              Colors.green,
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV exported successfully')),
                );
              },
            ),
            _buildExportOption(
              'Email Statement',
              Icons.email,
              Colors.blue,
              () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Statement sent to your email')),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
