// lib/presentation/screens/provider/jobs/provider_quote_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProviderQuoteDetailScreen extends StatelessWidget {
  final String quoteRequestId;

  const ProviderQuoteDetailScreen({Key? key, required this.quoteRequestId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Quote Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quote_requests')
            .doc(quoteRequestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Quote not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status']?.toString() ?? 'pending';
          final clientName = data['clientName']?.toString() ?? 'Client';
          final category = data['category']?.toString() ?? 'Service';
          final description = data['description']?.toString() ?? '';
          final address = data['address']?.toString() ?? '—';
          final photos = data['photos'] as List? ?? [];
          final quoteData = data['quote'] as Map<String, dynamic>?;
          final lineItems = quoteData?['lineItems'] as List? ?? [];
          final total = (quoteData?['total'] as num?)?.toDouble();
          final notes = quoteData?['notes']?.toString() ?? '';
          final createdAt =
              (data['createdAt'] as dynamic)?.toDate?.call() as DateTime?;
          final quotedAt =
              (quoteData?['quotedAt'] as dynamic)?.toDate?.call() as DateTime?;
          final validUntil = (quoteData?['validUntil'] as dynamic)
              ?.toDate
              ?.call() as DateTime?;
          final scheduledDate = data['scheduledDate'];
          final preferredFrom = data['preferredDateFrom']?.toString() ?? '';
          final preferredTo = data['preferredDateTo']?.toString() ?? '';

          Color statusColor;
          String statusLabel;
          IconData statusIcon;

          switch (status) {
            case 'pending':
              statusColor = Colors.orange;
              statusLabel = 'Awaiting Your Quote';
              statusIcon = Icons.hourglass_top;
              break;
            case 'quoted':
              statusColor = Colors.blue;
              statusLabel = 'Quote Sent';
              statusIcon = Icons.send_outlined;
              break;
            case 'accepted':
              statusColor = Colors.green;
              statusLabel = 'Client Accepted';
              statusIcon = Icons.check_circle_outline;
              break;
            case 'declined':
            case 'provider_declined':
              statusColor = Colors.red;
              statusLabel = 'Declined';
              statusIcon = Icons.cancel_outlined;
              break;
            case 'completed':
              statusColor = Colors.green;
              statusLabel = 'Completed';
              statusIcon = Icons.task_alt;
              break;
            default:
              statusColor = Colors.grey;
              statusLabel = status;
              statusIcon = Icons.info_outline;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Status banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusLabel,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor)),
                          if (createdAt != null)
                            Text('Received ${_fmt(createdAt)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor.withValues(alpha: 0.8))),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Reference
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: quoteRequestId));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Reference copied'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.tag, size: 15, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text('Quote Reference',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const Spacer(),
                    Text(quoteRequestId,
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 12, color: Colors.grey[500]),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Client info
              _sectionTitle('Client'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 8,
                        offset: Offset(0, 2))
                  ],
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[200],
                    child: Text(clientName[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(clientName,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(category,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600])),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Request details
              _sectionTitle('Request Details'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        _detailRow(Icons.description_outlined, 'Description',
                            description),
                        const SizedBox(height: 10),
                      ],
                      _detailRow(
                          Icons.location_on_outlined, 'Address', address),
                      if (preferredFrom.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _detailRow(
                            Icons.calendar_today_outlined,
                            'Preferred Dates',
                            preferredTo.isNotEmpty
                                ? '$preferredFrom – $preferredTo'
                                : preferredFrom),
                      ],
                      if (scheduledDate != null) ...[
                        const SizedBox(height: 10),
                        _detailRow(Icons.event_outlined, 'Scheduled',
                            _fmtDynamic(scheduledDate)),
                      ],
                    ]),
              ),

              // Client photos
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle('Client Photos'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    itemBuilder: (_, i) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(photos[i].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.image,
                                    color: Colors.grey[400]))),
                      ),
                    ),
                  ),
                ),
              ],

              // Your quote
              if (quoteData != null) ...[
                const SizedBox(height: 16),
                _sectionTitle('Your Quote'),
                if (quotedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Sent ${_fmt(quotedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
                if (validUntil != null)
                  Text('Valid until ${_fmt(validUntil)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    ...lineItems.asMap().entries.map((e) {
                      final item = e.value as Map<String, dynamic>;
                      final isLast = e.key == lineItems.length - 1;
                      return Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    item['description']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13))),
                            Text(
                                'R ${((item['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        if (!isLast)
                          Divider(height: 1, color: Colors.grey.shade200),
                      ]);
                    }),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(11),
                            bottomRight: Radius.circular(11)),
                      ),
                      child: Row(children: [
                        const Expanded(
                            child: Text('Total',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold))),
                        Text('R ${total?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ]),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(notes,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade800))),
                        ]),
                  ),
                ],
              ],

              const SizedBox(height: 40),
            ]),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: Colors.grey[500]),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(value, style: const TextStyle(fontSize: 13, height: 1.3)),
        ]),
      ),
    ]);
  }

  String _fmt(DateTime d) {
    return DateFormat('dd MMM yyyy').format(d);
  }

  String _fmtDynamic(dynamic ts) {
    if (ts is Timestamp)
      return DateFormat('dd MMM yyyy · HH:mm').format(ts.toDate());
    if (ts is String) {
      final d = DateTime.tryParse(ts);
      if (d != null) return DateFormat('dd MMM yyyy · HH:mm').format(d);
    }
    return '—';
  }
}
