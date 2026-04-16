// lib/presentation/screens/my_tickets_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({Key? key}) : super(key: key);

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Support Tickets',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .where('userId', isEqualTo: _uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No tickets yet',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        Text('Submit a ticket from Help & Support',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[400])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildTicketCard(docs[index].id, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildTicketCard(String ticketId, Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'open';
    final subject = data['subject']?.toString() ?? '—';
    final category = data['category']?.toString() ?? '—';
    final unreadByUser = data['unreadByUser'] == true;

    final updatedAt = data['updatedAt'] is Timestamp
        ? (data['updatedAt'] as Timestamp).toDate()
        : DateTime.now();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'open':
        statusColor = Colors.orange;
        statusIcon = Icons.radio_button_unchecked;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.autorenew;
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'closed':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserTicketDetailScreen(
            ticketId: ticketId,
            ticketData: data,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: unreadByUser ? Colors.blue.shade200 : Colors.grey.shade200,
              width: unreadByUser ? 1.5 : 1),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unreadByUser)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                              color: Colors.blue, shape: BoxShape.circle),
                        ),
                      Expanded(
                        child: Text(subject,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: unreadByUser
                                    ? FontWeight.bold
                                    : FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(category,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text(_timeAgo(updatedAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.replaceAll('_', ' '),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ============================================================================
// USER TICKET DETAIL — reply thread
// ============================================================================

class UserTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticketData;

  const UserTicketDetailScreen({
    Key? key,
    required this.ticketId,
    required this.ticketData,
  }) : super(key: key);

  @override
  State<UserTicketDetailScreen> createState() => _UserTicketDetailScreenState();
}

class _UserTicketDetailScreenState extends State<UserTicketDetailScreen> {
  final _replyCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark as read by user
    FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(widget.ticketId)
        .update({'unreadByUser': false});
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west4')
          .httpsCallable('replyToTicket');
      await callable.call({
        'ticketId': widget.ticketId,
        'message': _replyCtrl.text.trim(),
      });
      _replyCtrl.clear();
    } catch (e) {
      _showSnack('Failed to send reply: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.ticketData['subject']?.toString() ?? '—';
    final status = widget.ticketData['status']?.toString() ?? 'open';
    final category = widget.ticketData['category']?.toString() ?? '—';

    Color statusColor;
    switch (status) {
      case 'open':
        statusColor = Colors.orange;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        break;
      case 'resolved':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    final isClosed = status == 'closed' || status == 'resolved';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(subject,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          // Ticket info
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(category,
                      style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                ),
              ],
            ),
          ),

          // Reply thread
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .doc(widget.ticketId)
                  .collection('replies')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final replies = snapshot.data?.docs ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: replies.length,
                  itemBuilder: (context, index) {
                    final data = replies[index].data() as Map<String, dynamic>;
                    return _buildReplyBubble(data);
                  },
                );
              },
            ),
          ),

          // Reply input (disabled if closed/resolved)
          if (isClosed)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: Colors.grey.shade50,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This ticket has been $status. Open a new ticket if you need further help.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Add a reply or more details...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSending ? null : _sendReply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.all(14),
                      shape: const CircleBorder(),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyBubble(Map<String, dynamic> data) {
    final isAdmin = data['senderType'] == 'admin';
    final message = data['message']?.toString() ?? '';
    final senderName = isAdmin ? 'Support Team' : 'You';
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              '$senderName · ${_fmt(createdAt)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAdmin ? Colors.grey.shade100 : Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isAdmin ? 0 : 12),
                  bottomRight: Radius.circular(isAdmin ? 12 : 0),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                    fontSize: 13,
                    color: isAdmin ? Colors.black87 : Colors.white,
                    height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
