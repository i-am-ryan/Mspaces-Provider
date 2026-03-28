// lib/presentation/widgets/common/report_content_widget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportContentWidget extends StatelessWidget {
  final String contentType; // review, profile, message, booking
  final String contentId;
  final String contentPreview;
  final String reportedUserId;
  final String reportedUserName;
  final String? conversationId;

  const ReportContentWidget({
    Key? key,
    required this.contentType,
    required this.contentId,
    required this.contentPreview,
    required this.reportedUserId,
    required this.reportedUserName,
    this.conversationId,
  }) : super(key: key);

  static const _reasons = [
    'Offensive or abusive language',
    'Harassment or bullying',
    'Fake or misleading content',
    'Spam',
    'Inappropriate content',
    'Fraud or scam',
    'Other',
  ];

  void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ReportSheet(
        contentType: contentType,
        contentId: contentId,
        contentPreview: contentPreview,
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        conversationId: conversationId,
        reasons: _reasons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.flag_outlined, size: 14, color: Colors.red.shade700),
          const SizedBox(width: 4),
          Text('Report',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final String contentType;
  final String contentId;
  final String contentPreview;
  final String reportedUserId;
  final String reportedUserName;
  final String? conversationId;
  final List<String> reasons;

  const _ReportSheet({
    required this.contentType,
    required this.contentId,
    required this.contentPreview,
    required this.reportedUserId,
    required this.reportedUserName,
    this.conversationId,
    required this.reasons,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selectedReason;
  final _detailsCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      final reporterName = userDoc.data()?['displayName']?.toString() ??
          userDoc.data()?['fullName']?.toString() ??
          'User';

      await FirebaseFirestore.instance.collection('content_reports').add({
        'contentType': widget.contentType,
        'contentId': widget.contentId,
        'contentPreview': widget.contentPreview,
        'reportedUserId': widget.reportedUserId,
        'reportedUserName': widget.reportedUserName,
        'conversationId': widget.conversationId,
        'reportedById': user?.uid ?? '',
        'reportedByName': reporterName,
        'reason': _selectedReason,
        'details': _detailsCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        if (_submitted) ...[
          // Success state
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text('Report Submitted',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              'Thank you for reporting this content. Our moderation team will review it within 3-5 business days.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ),
        ] else ...[
          // Report form
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.flag_outlined,
                  color: Colors.red.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Report ${widget.contentType[0].toUpperCase()}${widget.contentType.substring(1)}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('by ${widget.reportedUserName}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),

          // Content preview
          if (widget.contentPreview.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                '"${widget.contentPreview}"',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Reason selection
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Reason for report',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          ...widget.reasons.map((reason) => GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedReason == reason
                        ? Colors.black
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _selectedReason == reason
                            ? Colors.black
                            : Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(reason,
                          style: TextStyle(
                              fontSize: 13,
                              color: _selectedReason == reason
                                  ? Colors.white
                                  : Colors.black)),
                    ),
                    if (_selectedReason == reason)
                      const Icon(Icons.check, color: Colors.white, size: 16),
                  ]),
                ),
              )),
          const SizedBox(height: 12),

          // Additional details
          TextField(
            controller: _detailsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedReason == null || _isSubmitting)
                  ? null
                  : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Report',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }
}
