// lib/presentation/screens/provider/notifications/provider_notifications_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<ProviderNotificationsScreen> createState() =>
      _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState
    extends State<ProviderNotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      _notifications = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'docId': doc.id,
          ...data,
          'createdAtDt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> n) async {
    if (n['read'] == true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .doc(n['docId']?.toString())
          .update({'read': true});
      setState(() => n['read'] = true);
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final n in _notifications) {
        if (n['read'] != true) {
          batch.update(
            FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .collection('notifications')
                .doc(n['docId']?.toString()),
            {'read': true},
          );
        }
      }
      await batch.commit();
      setState(() {
        for (final n in _notifications) n['read'] = true;
      });
    } catch (_) {}
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Delete all notifications?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete All',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final n in _notifications) {
        final docId = n['docId']?.toString();
        if (docId != null) {
          batch.delete(FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .collection('notifications')
              .doc(docId));
        }
      }
      await batch.commit();
      if (mounted) setState(() => _notifications.clear());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _onTap(Map<String, dynamic> n) {
    _markAsRead(n);
    final type = n['type']?.toString() ?? '';
    final bookingId = n['bookingId']?.toString();
    final invoiceId = n['invoiceId']?.toString();

    switch (type) {
      case 'quote_accepted':
      case 'new_booking':
      case 'booking_confirmed':
      case 'deposit_required':
      case 'payment_received':
      case 'provider_en_route':
        if (bookingId != null) {
          context.push('/job-detail', extra: bookingId);
        } else {
          context.push('/active-jobs');
        }
        break;
      case 'deposit_invoice':
      case 'invoice':
        if (invoiceId != null) {
          context.push('/provider-invoice-detail', extra: invoiceId);
        } else {
          context.push('/provider-earnings');
        }
        break;
      case 'payout_requested':
      case 'payout_approved':
      case 'payout_paid':
        context.push('/provider-earnings');
        break;
      case 'new_job_request':
        context.push('/job-requests');
        break;
      default:
        context.push('/provider-dashboard');
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'quote_accepted':
        return Icons.request_quote_outlined;
      case 'new_booking':
      case 'booking_confirmed':
        return Icons.calendar_today_outlined;
      case 'payment_received':
        return Icons.payments_outlined;
      case 'deposit_required':
      case 'deposit_invoice':
        return Icons.savings_outlined;
      case 'new_job_request':
        return Icons.work_outline;
      case 'provider_en_route':
        return Icons.navigation_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'payment_received':
      case 'deposit_invoice':
        return Colors.green;
      case 'quote_accepted':
      case 'booking_confirmed':
        return Colors.blue;
      case 'deposit_required':
        return Colors.orange;
      case 'new_job_request':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] != true).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notifications',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          if (unreadCount > 0)
            Text('$unreadCount unread',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: 'Clear all',
              onPressed: _deleteAllNotifications,
            ),
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No notifications',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[500])),
                    ]))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isUnread = n['read'] != true;
                      final type = n['type']?.toString();
                      final color = _colorForType(type);

                      return Dismissible(
                        key: Key(n['docId']?.toString() ?? i.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          final docId = n['docId']?.toString();
                          setState(() => _notifications.removeAt(i));
                          if (docId != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .collection('notifications')
                                .doc(docId)
                                .delete();
                          }
                        },
                        child: InkWell(
                          onTap: () => _onTap(n),
                          child: Container(
                            color: isUnread
                                ? Colors.blue.shade50.withValues(alpha: 0.5)
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(_iconForType(type),
                                        color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                              child: Text(
                                                n['title']?.toString() ?? '',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: isUnread
                                                        ? FontWeight.bold
                                                        : FontWeight.w500),
                                              ),
                                            ),
                                            Text(
                                              _timeAgo(n['createdAtDt']
                                                  as DateTime?),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[400]),
                                            ),
                                          ]),
                                          const SizedBox(height: 4),
                                          Text(
                                            n['body']?.toString() ?? '',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                height: 1.4),
                                          ),
                                        ]),
                                  ),
                                  if (isUnread) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle),
                                    ),
                                  ],
                                ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
