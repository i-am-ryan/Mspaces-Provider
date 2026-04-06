// lib/presentation/widgets/common/banner_notification_overlay.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BannerNotificationOverlay extends StatefulWidget {
  final Widget child;
  const BannerNotificationOverlay({Key? key, required this.child})
      : super(key: key);

  @override
  State<BannerNotificationOverlay> createState() =>
      _BannerNotificationOverlayState();
}

class _BannerNotificationOverlayState extends State<BannerNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  StreamSubscription<QuerySnapshot>? _sub;
  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _current;
  bool _showing = false;
  Timer? _autoHideTimer;

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
    _listenToNotifications();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _listenToNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      for (final doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>;
          _queue.add({'docId': doc.doc.id, ...data});
          if (!_showing) _showNext();
        }
      }
    });
  }

  void _showNext() {
    if (_queue.isEmpty || !mounted) return;
    setState(() {
      _current = _queue.removeAt(0);
      _showing = true;
    });
    _controller.forward(from: 0);
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 120), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _autoHideTimer?.cancel();
    _controller.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showing = false;
        _current = null;
      });
      if (_queue.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 200), _showNext);
      }
    });
    _markCurrentAsRead();
  }

  void _markCurrentAsRead() {
    final docId = _current?['docId']?.toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (docId == null || uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(docId)
        .update({'read': true}).catchError((_) {});
  }

  void _onNextStep() {
    _dismiss();
    if (_current == null || !mounted) return;
    final type = _current!['type']?.toString() ?? '';
    final bookingId = _current!['bookingId']?.toString();
    final invoiceId = _current!['invoiceId']?.toString();
    final quoteRequestId = _current!['quoteRequestId']?.toString();
    final serviceRequestId = _current!['serviceRequestId']?.toString();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      switch (type) {
        case 'deposit_required':
        case 'pay_callout':
        case 'pay_deposit':
          if (invoiceId != null) {
            context.push('/provider-earnings');
          } else if (bookingId != null) {
            FirebaseFirestore.instance
                .collection('invoices')
                .where('bookingId', isEqualTo: bookingId)
                .where('status', isEqualTo: 'outstanding')
                .limit(1)
                .get()
                .then((snap) {
              if (snap.docs.isNotEmpty && mounted) {
                context.push('/provider-earnings',
                    extra: {'invoiceId': snap.docs.first.id});
              } else if (mounted) {
                context.push('/provider-earnings');
              }
            });
          } else {
            context.push('/provider-earnings');
          }
          break;
        case 'booking_confirmed':
        case 'provider_en_route':
        case 'provider_arrived':
        case 'booking_rescheduled':
        case 'rescheduled_pending_client':
        case 'deposit_invoice':
        case 'booking_submitted':
          if (bookingId != null) {
            context.push('/provider-job-detail', extra: bookingId);
          } else {
            context.push('/provider-active-jobs');
          }
          break;
        case 'new_quote':
        case 'quote_ready':
        case 'quote_received':
        case 'quote_request_sent':
          if (quoteRequestId != null) {
            context.push('/provider-job-requests');
          } else {
            context.push('/provider-active-jobs');
          }
          break;
        case 'service_request':
        case 'service_request_update':
          if (serviceRequestId != null) {
            context.push('/provider-job-requests');
          } else {
            context.push('/provider-job-requests');
          }
          break;
        case 'invoice':
        case 'invoice_paid':
        case 'payment_received':
          if (invoiceId != null) {
            context.push('/invoice-detail', extra: invoiceId);
          } else {
            context.push('/provider-earnings');
          }
          break;
        default:
          context.push('/provider-notifications');
      }
    });
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'deposit_required':
      case 'pay_callout':
      case 'pay_deposit':
        return Icons.payment_outlined;
      case 'booking_confirmed':
        return Icons.event_available_outlined;
      case 'provider_en_route':
        return Icons.navigation_outlined;
      case 'provider_arrived':
        return Icons.location_on_outlined;
      case 'booking_rescheduled':
      case 'rescheduled_pending_client':
        return Icons.event_repeat_outlined;
      case 'new_quote':
      case 'quote_ready':
      case 'quote_received':
        return Icons.request_quote_outlined;
      case 'service_request':
      case 'service_request_update':
        return Icons.build_outlined;
      case 'payment_received':
        return Icons.payments_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _getNextStepLabel(String? type) {
    switch (type) {
      case 'deposit_required':
      case 'pay_callout':
      case 'pay_deposit':
        return 'Pay Now';
      case 'booking_confirmed':
      case 'provider_arrived':
        return 'View Booking';
      case 'provider_en_route':
        return 'Track Provider';
      case 'booking_rescheduled':
      case 'rescheduled_pending_client':
        return 'Review Date';
      case 'new_quote':
      case 'quote_ready':
      case 'quote_received':
        return 'View Quote';
      case 'service_request':
      case 'service_request_update':
        return 'View Request';
      case 'payment_received':
        return 'View Invoice';
      default:
        return 'View';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_showing && _current != null)
        Positioned.fill(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon circle
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 1.5),
                                ),
                                child: Icon(
                                  _getIcon(_current!['type']?.toString()),
                                  color: Colors.black,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Divider
                              const Divider(color: Colors.black12, height: 1),
                              const SizedBox(height: 20),

                              // Title
                              Text(
                                _current!['title']?.toString() ??
                                    'Notification',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Body
                              Text(
                                _current!['body']?.toString() ?? '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  height: 1.5,
                                  fontWeight: FontWeight.normal,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Buttons
                              Row(children: [
                                // Dismiss — white with black border
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _dismiss,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.black, width: 1.5),
                                      ),
                                      child: const Text(
                                        'Dismiss',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Next step — black fill
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _onNextStep,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getNextStepLabel(
                                            _current!['type']?.toString()),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
