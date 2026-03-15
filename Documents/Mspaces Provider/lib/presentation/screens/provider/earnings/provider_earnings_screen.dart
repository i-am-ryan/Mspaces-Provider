import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({Key? key}) : super(key: key);

  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  String _selectedPeriod = 'This Week';

  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  final Map<String, dynamic> _earningsData = {
    'Today': {
      'total': 'R1,250',
      'jobs': 2,
      'hours': '4h 30m',
      'avgPerJob': 'R625',
    },
    'This Week': {
      'total': 'R8,450',
      'jobs': 12,
      'hours': '32h',
      'avgPerJob': 'R704',
    },
    'This Month': {
      'total': 'R32,500',
      'jobs': 45,
      'hours': '128h',
      'avgPerJob': 'R722',
    },
    'All Time': {
      'total': 'R156,800',
      'jobs': 234,
      'hours': '645h',
      'avgPerJob': 'R670',
    },
  };

  final List<Map<String, dynamic>> _recentEarnings = const [
    {
      'clientName': 'Sarah Johnson',
      'service': 'Pipe Repair',
      'date': 'Today, 09:00 AM',
      'amount': 'R850',
      'status': 'completed',
    },
    {
      'clientName': 'Michael Chen',
      'service': 'Drain Cleaning',
      'date': 'Today, 02:00 PM',
      'amount': 'R400',
      'status': 'pending',
    },
    {
      'clientName': 'Emily Brown',
      'service': 'Water Heater Installation',
      'date': 'Yesterday',
      'amount': 'R2,500',
      'status': 'completed',
    },
    {
      'clientName': 'David Williams',
      'service': 'Toilet Repair',
      'date': '2 days ago',
      'amount': 'R450',
      'status': 'completed',
    },
    {
      'clientName': 'Lisa Anderson',
      'service': 'Faucet Replacement',
      'date': '3 days ago',
      'amount': 'R650',
      'status': 'completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currentData = _earningsData[_selectedPeriod]!;

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
          'Earnings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/provider-transactions'),
            icon: const Icon(Icons.receipt_long, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            Container(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            period,
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

            // Total earnings card
            Container(
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
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Earnings',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentData['total'],
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedPeriod,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEarningsStat(
                        'Jobs',
                        currentData['jobs'].toString(),
                        Icons.work_outline,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white24,
                      ),
                      _buildEarningsStat(
                        'Hours',
                        currentData['hours'],
                        Icons.access_time,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white24,
                      ),
                      _buildEarningsStat(
                        'Avg/Job',
                        currentData['avgPerJob'],
                        Icons.trending_up,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Withdraw',
                      Icons.account_balance_wallet,
                      Colors.green,
                      () => context.push('/provider-payout-settings'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'History',
                      Icons.history,
                      Colors.blue,
                      () => context.push('/provider-transactions'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'Reports',
                      Icons.analytics,
                      Colors.orange,
                      () {},
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Balance info
            _buildBalanceCard(),

            const SizedBox(height: 24),

            // Recent earnings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Earnings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/provider-transactions'),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _recentEarnings.length,
              itemBuilder: (context, index) {
                return _buildEarningItem(_recentEarnings[index]);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Balance',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'R4,250.00',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => context.push('/provider-payout-settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Withdraw',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceItem('Pending', 'R1,250.00', Colors.orange),
              Container(height: 30, width: 1, color: Colors.grey[200]),
              _buildBalanceItem('Processing', 'R850.00', Colors.blue),
              Container(height: 30, width: 1, color: Colors.grey[200]),
              _buildBalanceItem('This Week', 'R8,450.00', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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

  Widget _buildEarningItem(Map<String, dynamic> earning) {
    final isPending = earning['status'] == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(
        children: [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  earning['service'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${earning['clientName']} • ${earning['date']}',
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
                earning['amount'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                    color: isPending ? Colors.orange[700] : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
