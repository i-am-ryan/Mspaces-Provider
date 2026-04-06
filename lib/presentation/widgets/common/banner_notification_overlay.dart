// lib/presentation/widgets/common/banner_notification_overlay.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps a screen and shows a sliding banner for new notifications.
/// Usage: wrap your Scaffold with BannerNotificationOverlay
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
  late Animation<Offset> _slideAnimation;

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
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

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
          final notification = {
            'docId': doc.doc.id,
            ...data,
          };
          _queue.add(notification);
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
    // Auto-hide after 120 seconds
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
      // Show next if queued
      if (_queue.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), _showNext);
      }
    });
    // Mark as read
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
                context.push('/pay-invoice',
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
          if (bookingId != null) {
            FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .get()
                .then((doc) {
              if (doc.exists && mounted) {
                context.push('/provider-job-detail', extra: bookingId);
              } else if (mounted) {
                context.push('/provider-active-jobs');
              }
            });
          } else {
            context.push('/provider-active-jobs');
          }
          break;

        case 'new_quote':
        case 'quote_ready':
          if (quoteRequestId != null) {
            context.push('/quote-detail/$quoteRequestId');
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

  Color _getBannerColor(String? type) {
    switch (type) {
      case 'deposit_required':
      case 'pay_callout':
      case 'pay_deposit':
        return const Color(0xFFB71C1C); // deep red
      case 'booking_confirmed':
      case 'provider_arrived':
        return const Color(0xFF1B5E20); // deep green
      case 'provider_en_route':
        return const Color(0xFF0D47A1); // deep blue
      case 'booking_rescheduled':
      case 'rescheduled_pending_client':
        return const Color(0xFF4A148C); // deep purple
      case 'new_quote':
      case 'quote_ready':
        return const Color(0xFF1565C0); // blue
      case 'service_request':
      case 'service_request_update':
        return const Color(0xFFE65100); // deep orange
      case 'invoice':
      case 'payment_received':
        return const Color(0xFF2E7D32); // green
      default:
        return const Color(0xFF212121); // near black
    }
  }

  IconData _getBannerIcon(String? type) {
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
        return 'View Booking';
      case 'provider_en_route':
        return 'Track Provider';
      case 'provider_arrived':
        return 'View Booking';
      case 'booking_rescheduled':
      case 'rescheduled_pending_client':
        return 'Review Date';
      case 'new_quote':
      case 'quote_ready':
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
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: SlideTransition(
              position: _slideAnimation,
              child: GestureDetector(
                onTap: _onNextStep,
                onVerticalDragEnd: (details) {
                  if (details.velocity.pixelsPerSecond.dy < -100) _dismiss();
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  decoration: BoxDecoration(
                    color: _getBannerColor(_current!['type']?.toString()),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getBannerIcon(_current!['type']?.toString()),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text content
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _current!['title']?.toString() ??
                                        'Notification',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _current!['body']?.toString() ?? '',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),

                                  // Buttons row
                                  Row(children: [
                                    // Dismiss button
                                    GestureDetector(
                                      onTap: _dismiss,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: const Text('Dismiss',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Next step button
                                    GestureDetector(
                                      onTap: _onNextStep,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getNextStepLabel(
                                              _current!['type']?.toString()),
                                          style: TextStyle(
                                              color: _getBannerColor(
                                                  _current!['type']
                                                      ?.toString()),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ]),
                          ),

                          // Close X
                          GestureDetector(
                            onTap: _dismiss,
                            child: Icon(Icons.close,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 18),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
