// lib/presentation/screens/provider/jobs/job_detail_screen.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class JobDetailScreen extends StatefulWidget {
  final String bookingId;
  const JobDetailScreen({Key? key, required this.bookingId}) : super(key: key);
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isUpdating = false;
  bool _showCompletionForm = false;
  final _workNotesCtrl = TextEditingController();
  final List<File> _completionPhotos = [];
  final _imagePicker = ImagePicker();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<DocumentSnapshot> get _docStream => FirebaseFirestore.instance
      .collection('bookings')
      .doc(widget.bookingId)
      .snapshots();

  @override
  void dispose() {
    _workNotesCtrl.dispose();
    super.dispose();
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp)
      return DateFormat('dd MMM yyyy · HH:mm').format(ts.toDate());
    if (ts is String) {
      final d = DateTime.tryParse(ts);
      if (d != null) return DateFormat('dd MMM yyyy · HH:mm').format(d);
    }
    return '—';
  }

  String _formatAmount(dynamic v) {
    if (v == null) return 'R0';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return 'R${n.toStringAsFixed(0)}';
  }

  Future<void> _pickPhoto() async {
    if (_completionPhotos.length >= 6) {
      _snack('Maximum 6 photos', error: true);
      return;
    }
    final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null)
      setState(() => _completionPhotos.add(File(picked.path)));
  }

  Future<List<String>> _uploadPhotos() async {
    final urls = <String>[];
    for (int i = 0; i < _completionPhotos.length; i++) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('job_completions/$_uid/${widget.bookingId}/${ts}_$i.jpg');
      final task = await ref.putFile(_completionPhotos[i]);
      urls.add(await task.ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _startJob() async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('Job started!');
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showRescheduleDialog(BuildContext context, Map<String, dynamic> data) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Propose New Date'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Select a new date to propose to the client:',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setDialog(() => selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason for rescheduling (optional)',
                filled: true,
                fillColor: Colors.grey.shade50,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isUpdating = true);
                try {
                  await FirebaseFunctions.instanceFor(region: 'europe-west4')
                      .httpsCallable('rescheduleBooking')
                      .call({
                    'bookingId': widget.bookingId,
                    'newScheduledDate': selectedDate.toIso8601String(),
                    'message': messageCtrl.text.trim(),
                  });
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('New date proposed. Client notified.'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red));
                } finally {
                  if (mounted) setState(() => _isUpdating = false);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Send Proposal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markComplete(Map<String, dynamic> data) async {
    if (_workNotesCtrl.text.trim().isEmpty) {
      _snack('Please add work notes', error: true);
      return;
    }
    setState(() => _isUpdating = true);
    try {
      final photoUrls = await _uploadPhotos();
      final amount =
          data['total'] ?? data['estimatedPrice'] ?? data['amount'] ?? 0;

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'workNotes': _workNotesCtrl.text.trim(),
        'completionPhotos': photoUrls,
      });

      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(_uid)
          .collection('entries')
          .add({
        'bookingId': widget.bookingId,
        'clientName': data['clientName'] ?? '',
        'serviceCategory': data['serviceCategory'] ??
            data['category'] ??
            data['service'] ??
            '',
        'amount': amount,
        'type': 'earning',
        'status': 'completed',
        'providerId': _uid,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update provider job count
      await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(_uid)
          .update({
        'completedJobs': FieldValue.increment(1),
        'totalJobsCompleted': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

// Generate completion invoice via Cloud Function
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west4')
            .httpsCallable('generateJobCompletionInvoice');
        await callable.call({'bookingId': widget.bookingId});
      } catch (_) {}

      final clientId = data['clientId']?.toString() ?? '';
      if (clientId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(clientId)
            .collection('notifications')
            .add({
          'title': 'Job Completed',
          'body':
              'Your ${data['serviceCategory'] ?? data['category'] ?? 'service'} job has been completed.',
          'type': 'job_completed',
          'bookingId': widget.bookingId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) _showCompletionDialog();
    } catch (e) {
      if (mounted) _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration:
                BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
            child:
                const Icon(Icons.check_circle, size: 60, color: Colors.green),
          ),
          const SizedBox(height: 24),
          const Text('Job Completed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
              'Great work! The client has been notified and your earnings recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
                    icon: const Icon(Icons.arrow_back, color: Colors.black))),
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
                    icon: const Icon(Icons.arrow_back, color: Colors.black))),
            body: Center(
                child: Text('Booking not found.',
                    style: TextStyle(color: Colors.grey[600]))),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';
        final quoteRequestId = data['quoteRequestId']?.toString() ?? '';
        final refNumber =
            quoteRequestId.isNotEmpty ? quoteRequestId : widget.bookingId;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.black)),
            title: const Text('Job Details',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            actions: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: refNumber));
                  _snack('Reference copied');
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(children: [
                    Text(
                        refNumber.length > 14
                            ? '${refNumber.substring(0, 14)}...'
                            : refNumber,
                        style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 11, color: Colors.grey[600]),
                  ]),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildStatusBar(status),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildClientCard(data),
                      const SizedBox(height: 16),
                      _buildServiceDetails(data),
                      const SizedBox(height: 16),
                      _buildLocationCard(data),
                      const SizedBox(height: 16),
                      _buildDescriptionCard(data),
                      const SizedBox(height: 16),
                      _buildPriceCard(data),
                      if ((data['photos'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _buildClientPhotos(data['photos'] as List),
                      ],
                      if (_showCompletionForm || status == 'in_progress') ...[
                        const SizedBox(height: 16),
                        _buildCompletionForm(),
                      ],
                      const SizedBox(height: 100),
                    ]),
              ),
            ]),
          ),
          bottomNavigationBar: _buildBottomBar(status, data),
        );
      },
    );
  }

  Widget _buildStatusBar(String status) {
    Color color;
    String text;
    IconData icon;
    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = 'CONFIRMED';
        icon = Icons.check_circle_outline;
        break;
      case 'accepted':
        color = Colors.orange;
        text = 'ACCEPTED';
        icon = Icons.check_circle_outline;
        break;
      case 'in_progress':
        color = Colors.blue;
        text = 'IN PROGRESS';
        icon = Icons.build;
        break;
      case 'completed':
        color = Colors.purple;
        text = 'COMPLETED';
        icon = Icons.task_alt;
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
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1)),
      ]),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> d) {
    final clientName = d['clientName']?.toString() ?? '—';
    final clientPhone = d['clientPhone']?.toString() ?? '';
    final clientEmail = d['clientEmail']?.toString() ?? '';
    return _card(
        child: Row(children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[200],
        child: Text(clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 16),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(clientName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (clientPhone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(clientPhone,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]))
        ],
        if (clientEmail.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(clientEmail,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]))
        ],
      ])),
    ]));
  }

  Widget _buildServiceDetails(Map<String, dynamic> d) {
    final service = d['serviceCategory']?.toString() ??
        d['category']?.toString() ??
        d['service']?.toString() ??
        'Service';
    final scheduledDate = _formatDate(d['scheduledDate']);
    final source = d['source']?.toString() ?? '';
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.build_circle, color: Colors.blue[700], size: 24)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(service,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (source == 'quote')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade200)),
              child: Text('From Quote',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w600)),
            ),
        ])),
      ]),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 12),
      Row(children: [
        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scheduled',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(scheduledDate,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ]),
    ]));
  }

  Widget _buildLocationCard(Map<String, dynamic> d) {
    final address =
        d['address']?.toString() ?? d['location']?.toString() ?? '—';
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(address, style: const TextStyle(fontSize: 14))),
      ]),
    ]));
  }

  Widget _buildDescriptionCard(Map<String, dynamic> d) {
    final desc = d['serviceDescription']?.toString() ??
        d['description']?.toString() ??
        d['notes']?.toString() ??
        '';
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Job Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(desc.isNotEmpty ? desc : 'No description provided.',
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
    ]));
  }

  Widget _buildPriceCard(Map<String, dynamic> d) {
    final amount =
        _formatAmount(d['total'] ?? d['estimatedPrice'] ?? d['amount']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Earnings',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Agreed amount',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        Text(amount,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green)),
      ]),
    );
  }

  Widget _buildClientPhotos(List photos) {
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Client Photos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.only(right: 8),
            width: 80,
            height: 80,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(photos[i].toString(), fit: BoxFit.cover)),
          ),
        ),
      ),
    ]));
  }

  Widget _buildCompletionForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.assignment_turned_in_outlined,
              color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Text('Completion Report',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800)),
        ]),
        const SizedBox(height: 4),
        Text('Required before marking job as complete',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
        const SizedBox(height: 16),
        const Text('Work Done *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _workNotesCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Describe the work completed, materials used, any issues encountered...',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.blue.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.blue.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black, width: 1.5)),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Photos of Completed Work',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('${_completionPhotos.length}/6',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 4),
        Text('Upload photos showing the completed work',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            ..._completionPhotos.asMap().entries.map((e) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(e.value, fit: BoxFit.cover)),
                    Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _completionPhotos.removeAt(e.key)),
                          child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 12)),
                        )),
                  ],
                )),
            if (_completionPhotos.length < 6)
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200)),
                  child: Icon(Icons.add_a_photo_outlined,
                      color: Colors.blue.shade400, size: 24),
                ),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _buildBottomBar(String status, Map<String, dynamic> data) {
    if (status == 'completed') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -4))
        ]),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12)),
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
                ]),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -4))
      ]),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Pending provider confirmation — Confirm or Reschedule
          if (status == 'pending_provider_confirmation') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating
                    ? null
                    : () async {
                        setState(() => _isUpdating = true);
                        try {
                          await FirebaseFunctions.instanceFor(
                                  region: 'europe-west4')
                              .httpsCallable('confirmBookingDate')
                              .call({'bookingId': widget.bookingId});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Booking confirmed! Client notified to pay deposit.'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red));
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
                      },
                icon:
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Confirm Booking Date',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdating
                    ? null
                    : () => _showRescheduleDialog(context, data),
                icon: const Icon(Icons.calendar_today_outlined,
                    color: Colors.black),
                label: const Text('Propose New Date',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Show on-site quote button if callout fee paid
          //Assesment complete button
          if ((status == 'confirmed' || status == 'accepted') &&
              data['paymentStatus'] == 'callout_paid') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('bookings')
                        .doc(widget.bookingId)
                        .update({
                      'status': 'assessment_complete',
                      'assessmentCompletedAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  } catch (_) {}
                  if (!mounted) return;
                  context.push('/provider-create-quote', extra: {
                    'bookingId': widget.bookingId,
                    'clientId':
                        (data['clientId'] ?? data['userId'])?.toString() ?? '',
                    'clientName': data['clientName']?.toString() ?? 'Client',
                    'category': data['serviceCategory']?.toString() ??
                        data['category']?.toString() ??
                        'Service',
                    'address': data['address']?.toString() ?? '',
                    'description': data['description']?.toString() ?? '',
                    'providerId': data['providerId']?.toString() ?? _uid,
                    'providerName': data['providerName']?.toString() ?? '',
                  });
                },
                label: const Text('On-Site Assessment Complete',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Start Job button
          if (status == 'confirmed' || status == 'accepted') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _startJob,
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text('Start Job',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],

          //Complete Job Button
          if (status == 'in_progress') ...[
            if (!_showCompletionForm)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showCompletionForm = true),
                  icon: const Icon(Icons.assignment_turned_in,
                      color: Colors.white),
                  label: const Text('Mark as Complete',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : () => _markComplete(data),
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                  label: Text(
                      _isUpdating ? 'Submitting...' : 'Submit & Complete Job',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() => _showCompletionForm = false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1A000000)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 10,
                  offset: Offset(0, 4))
            ]),
        child: child,
      );
}
