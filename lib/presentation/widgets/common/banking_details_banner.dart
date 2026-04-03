// lib/presentation/widgets/common/banking_details_banner.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows a dismissible banner when banking details are missing.
/// Add this near the top of any home/dashboard screen.
class BankingDetailsBanner extends StatefulWidget {
  /// Route to push when user taps "Add Now"
  /// Client app: '/banking-details'
  /// Provider app: '/provider-payout-settings'
  final String route;

  const BankingDetailsBanner({Key? key, required this.route}) : super(key: key);

  @override
  State<BankingDetailsBanner> createState() => _BankingDetailsBannerState();
}

class _BankingDetailsBannerState extends State<BankingDetailsBanner> {
  bool _hasBanking = true; // default true to avoid flash
  bool _dismissed = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkBankingDetails();
  }

  Future<void> _checkBankingDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final hasBanking = data['hasBankingDetails'] as bool? ?? false;
      final banking = data['bankingDetails'] as Map?;
      final hasValidBanking = hasBanking ||
          (banking != null &&
              banking['accountNumber']?.toString().isNotEmpty == true);
      if (mounted) {
        setState(() {
          _hasBanking = hasValidBanking;
          _checked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || _hasBanking || _dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(children: [
        Icon(Icons.account_balance_outlined,
            color: Colors.orange.shade700, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Banking details missing',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800)),
            Text(
              'Add your banking details to receive payouts and refunds.',
              style: TextStyle(
                  fontSize: 12, color: Colors.orange.shade700, height: 1.3),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(children: [
          GestureDetector(
            onTap: () => context.push(widget.route),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Add Now',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: Text('Dismiss',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade600,
                    decoration: TextDecoration.underline)),
          ),
        ]),
      ]),
    );
  }
}
