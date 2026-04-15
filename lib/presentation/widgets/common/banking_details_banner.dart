// lib/presentation/widgets/common/banking_details_banner.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows a centre-screen overlay modal when banking details are missing.
/// Wrap the home/dashboard screen with this widget.
class BankingDetailsBanner extends StatefulWidget {
  final String route;
  final Widget child;

  const BankingDetailsBanner({
    Key? key,
    required this.route,
    required this.child,
  }) : super(key: key);

  @override
  State<BankingDetailsBanner> createState() => _BankingDetailsBannerState();
}

class _BankingDetailsBannerState extends State<BankingDetailsBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _showing = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _checkBankingDetails();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      if (!hasValidBanking && mounted) {
        setState(() {
          _showing = true;
          _checked = true;
        });
        _controller.forward();
      } else {
        if (mounted) setState(() => _checked = true);
      }
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) setState(() => _showing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showing)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_outlined,
                                size: 28, color: Colors.black),
                          ),
                          const SizedBox(height: 16),
                          // Title
                          const Text(
                            'Banking Details Missing',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Body
                          const Text(
                            'Add your banking details to receive payouts and refunds.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                                height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Add Now button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                _dismiss();
                                context.push(widget.route);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Add Banking Details',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Dismiss
                          TextButton(
                            onPressed: _dismiss,
                            child: const Text('Remind me later',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF999999))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
