import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class JobDetailScreen extends StatefulWidget {
  final String bookingId;

  const JobDetailScreen({Key? key, required this.bookingId}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isUpdating = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<DocumentSnapshot> get _docStream => FirebaseFirestore.instance
      .collection('bookings')
      .doc(widget.bookingId)
      .snapshots();

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return '—';
  }

  String _formatAmount(dynamic v) {
    if (v == null) return 'R0';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return 'R${n.toStringAsFixed(0)}';
  }

  Future<void> _updateStatus(String newStatus,
      Map<String, dynamic> data) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'in_progress') {
        updates['startedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == 'completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();

        // Write to transactions/{uid}/entries
        final amount = data['estimatedPrice'] ?? data['amount'] ?? 0;
        await FirebaseFirestore.instance
            .collection('transactions')
            .doc(_uid)
            .collection('entries')
            .add({
          'bookingId': widget.bookingId,
          'clientName': data['clientName'] ?? '',
          'serviceCategory':
              data['serviceCategory'] ?? data['service'] ?? '',
          'amount': amount,
          'type': 'earning',
          'status': 'completed',
          'providerId': _uid,
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update(updates);

      if (mounted && newStatus == 'completed') {
        _showCompletionDialog();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'in_progress'
                ? 'Job started!'
                : 'Status updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Update failed. Try again.'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.green[50], shape: BoxShape.circle),
              child: const Icon(Icons.check_circle,
                  size: 60, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text('Job Completed!',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Great work! The client will be notified and your earnings have been recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/provider-dashboard');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Dashboard',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _docStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
            body: const Center(
                child: CircularProgressIndicator(color: Colors.black)),
          );
        }

        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
            body: Center(
              child: Text('Booking not found.',
                  style: TextStyle(color: Colors.grey[600])),
            ),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.black),
            ),
            title: const Text('Job Details',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBar(status),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildClientCard(data),
                      const SizedBox(height: 20),
                      _buildServiceDetails(data),
                      const SizedBox(height: 20),
                      _buildLocationCard(data),
                      const SizedBox(height: 20),
                      _buildDescriptionCard(data),
                      const SizedBox(height: 20),
                      _buildPriceCard(data),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar:
              _buildBottomBar(status, data),
        );
      },
    );
  }

  Widget _buildStatusBar(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'accepted':
        color = Colors.orange;
        text = 'ACCEPTED';
        icon = Icons.check_circle_outline;
        break;
      case 'in_progress':
        color = Colors.green;
        text = 'IN PROGRESS';
        icon = Icons.build;
        break;
      case 'completed':
        color = Colors.purple;
        text = 'COMPLETED';
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
        icon = Icons.hourglass_empty;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> d) {
    final clientName = d['clientName'] as String? ?? '—';
    final clientPhone = d['clientPhone'] as String? ?? '';

    return Container(
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.person, size: 28, color: Colors.black54),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clientName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (clientPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(clientPhone,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetails(Map<String, dynamic> d) {
    final service =
        d['serviceCategory'] ?? d['service'] ?? d['serviceType'] ?? 'Service';
    final scheduledDate = _formatDate(d['scheduledDate']);
    final scheduledTime = d['scheduledTime'] as String? ?? '—';

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.build_circle,
                    color: Colors.blue[700], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.toString(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Service',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDetailItem(
                  Icons.calendar_today, 'Date', scheduledDate),
              const SizedBox(width: 24),
              _buildDetailItem(
                  Icons.access_time, 'Time', scheduledTime),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600])),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> d) {
    final address = d['address'] ?? d['location'] ?? '—';

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
                child: Icon(Icons.map, size: 40, color: Colors.grey)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(address.toString(),
                    style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(Map<String, dynamic> d) {
    final desc =
        d['serviceDescription'] ?? d['description'] ?? d['notes'] ?? '';

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Job Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            desc.toString().isNotEmpty
                ? desc.toString()
                : 'No description provided.',
            style: TextStyle(
                fontSize: 14, color: Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> d) {
    final amount =
        _formatAmount(d['estimatedPrice'] ?? d['amount']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Earnings',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text('Estimated amount',
                  style: TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ],
          ),
          Text(amount,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(String status, Map<String, dynamic> data) {
    if (status == 'completed') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(0, -4))
          ],
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.purple),
                SizedBox(width: 8),
                Text('Job Completed',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple)),
              ],
            ),
          ),
        ),
      );
    }

    final isAccepted = status == 'accepted';
    final buttonLabel = isAccepted ? 'Start Job' : 'Mark as Complete';
    final buttonColor = isAccepted ? Colors.orange : Colors.green;
    final nextStatus = isAccepted ? 'in_progress' : 'completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () => _updateStatus(nextStatus, data),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(buttonLabel,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
