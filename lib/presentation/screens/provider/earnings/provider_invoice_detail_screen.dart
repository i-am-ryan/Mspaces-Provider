// lib/presentation/screens/provider/earnings/provider_invoice_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProviderInvoiceDetailScreen extends StatelessWidget {
  final String invoiceId;

  const ProviderInvoiceDetailScreen({Key? key, required this.invoiceId})
      : super(key: key);

  double _providerAmount(Map<String, dynamic> inv) =>
      (inv['providerAmount'] as num?)?.toDouble() ??
      (inv['subtotal'] as num?)?.toDouble() ??
      (inv['total'] as num?)?.toDouble() ??
      0;

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
        title: const Text('Invoice Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .doc(invoiceId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.black));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return Center(
                child: Text('Invoice not found.',
                    style: TextStyle(color: Colors.grey[600])));
          }

          final inv = snap.data!.data() as Map<String, dynamic>;
          final invoiceNumber = inv['invoiceNumber']?.toString() ?? invoiceId;
          final clientName = inv['clientName']?.toString() ?? 'Client';
          final category = inv['serviceCategory']?.toString() ?? 'Service';
          final status = inv['status']?.toString() ?? 'outstanding';
          final isPaid = status == 'paid';
          final providerAmt = _providerAmount(inv);
          final grandTotal = (inv['grandTotal'] as num?)?.toDouble() ??
              (inv['total'] as num?)?.toDouble() ??
              0;
          final txFee = (inv['transactionFee'] as num?)?.toDouble() ?? 0;
          final platformFee = (inv['platformFee'] as num?)?.toDouble() ?? 0;
          final outstandingBalance =
              (inv['outstandingBalance'] as num?)?.toDouble() ?? grandTotal;
          final callOutFeePaid =
              (inv['callOutFeePaid'] as num?)?.toDouble() ?? 0;
          final lineItems = inv['lineItems'] as List? ?? [];
          final createdAt = (inv['createdAt'] as Timestamp?)?.toDate();
          final dueDate = (inv['dueDate'] as Timestamp?)?.toDate();
          final bookingId = inv['bookingId']?.toString() ?? '';
          final quoteRequestId = inv['quoteRequestId']?.toString() ?? '';
          final isOverdue =
              dueDate != null && dueDate.isBefore(DateTime.now()) && !isPaid;

          Color statusColor = isPaid
              ? Colors.green
              : isOverdue
                  ? Colors.red
                  : Colors.orange;
          String statusLabel = isPaid
              ? 'Paid'
              : isOverdue
                  ? 'Overdue'
                  : 'Outstanding';

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
                  Icon(
                      isPaid
                          ? Icons.check_circle_outline
                          : isOverdue
                              ? Icons.warning_outlined
                              : Icons.receipt_outlined,
                      color: statusColor,
                      size: 20),
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
                          if (dueDate != null && !isPaid)
                            Text(
                              isOverdue
                                  ? 'Was due ${DateFormat('dd MMM yyyy').format(dueDate)}'
                                  : 'Due ${DateFormat('dd MMM yyyy').format(dueDate)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor.withValues(alpha: 0.8)),
                            ),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Invoice number
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: invoiceNumber));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Invoice number copied'),
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
                    Text('Invoice Number',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const Spacer(),
                    Text(invoiceNumber,
                        style: const TextStyle(
                            fontSize: 12,
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
                    child: Text(
                      clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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

              // Amount breakdown
              _sectionTitle('Payment Breakdown'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  // Line items
                  ...lineItems.asMap().entries.map((e) {
                    final item = e.value as Map<String, dynamic>;
                    final desc = item['description']?.toString() ?? '';
                    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(children: [
                          Expanded(
                              child: Text(desc,
                                  style: const TextStyle(fontSize: 13))),
                          Text('R ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                    ]);
                  }),

                  // Your amount (provider share)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Your Amount',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              Text('Before platform & transaction fees',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600])),
                            ]),
                      ),
                      Text('R ${providerAmt.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700)),
                    ]),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),

                  // Fees (info only)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Transaction fee (1.5%) + Platform fee (2%) = R ${(txFee + platformFee).toStringAsFixed(2)} charged to client',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ),
                    ]),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),

                  // Client total
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Expanded(
                          child: Text('Client Total (incl. fees)',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600]))),
                      Text('R ${grandTotal.toStringAsFixed(2)}',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ]),
                  ),

                  if (callOutFeePaid > 0) ...[
                    Divider(height: 1, color: Colors.grey.shade200),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(children: [
                        Expanded(
                            child: Text('Call-out fee paid',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]))),
                        Text('− R ${callOutFeePaid.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ]),
                    ),
                  ],

                  // Outstanding
                  if (!isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(11),
                          bottomRight: Radius.circular(11),
                        ),
                      ),
                      child: Row(children: [
                        Expanded(
                            child: Text('Client Outstanding Balance',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor))),
                        Text('R ${outstandingBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 16),

              // Dates
              _sectionTitle('Details'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  if (createdAt != null)
                    _detailRow('Invoice Date',
                        DateFormat('dd MMM yyyy').format(createdAt)),
                  if (dueDate != null) ...[
                    const SizedBox(height: 8),
                    _detailRow(
                        'Due Date', DateFormat('dd MMM yyyy').format(dueDate)),
                  ],
                  if (bookingId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow('Booking ID', bookingId),
                  ],
                  if (quoteRequestId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow('Quote Ref', quoteRequestId),
                  ],
                ]),
              ),

              const SizedBox(height: 40),
            ]),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _detailRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}
