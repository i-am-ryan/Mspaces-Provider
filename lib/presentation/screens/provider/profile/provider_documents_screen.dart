// lib/presentation/screens/provider/profile/provider_documents_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ProviderDocumentsScreen extends StatefulWidget {
  const ProviderDocumentsScreen({Key? key}) : super(key: key);

  @override
  State<ProviderDocumentsScreen> createState() =>
      _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState extends State<ProviderDocumentsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _documents = {};
  final Map<String, bool> _uploading = {};
  String? _providerDocId;

  final List<Map<String, dynamic>> _requiredDocs = [
    {
      'key': 'id_document',
      'title': 'ID / Passport Copy',
      'subtitle':
          'South African ID or valid passport. If registering as a company, provide the director\'s ID.',
      'icon': Icons.badge_outlined,
    },
    {
      'key': 'company_registration',
      'title': 'Company Registration (if applicable)',
      'subtitle':
          'CIPC company registration document (only required if operating as a company)',
      'icon': Icons.business_outlined,
      'optional': true,
    },
    {
      'key': 'registration_body',
      'title': 'Professional Registration',
      'subtitle':
          'Relevant trade/body registration certificate (e.g. ECSA, PLASA, Master Builders)',
      'icon': Icons.workspace_premium_outlined,
    },
    {
      'key': 'bank_confirmation',
      'title': 'Bank Account Confirmation',
      'subtitle': 'Bank-stamped confirmation letter (not older than 3 months)',
      'icon': Icons.account_balance_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Get provider doc ID
      final snap = await FirebaseFirestore.instance
          .collection('service_providers')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        _providerDocId = snap.docs.first.id;
        final data = snap.docs.first.data();
        if (mounted) {
          setState(() {
            _documents = Map<String, dynamic>.from(
                data['verificationDocuments'] as Map? ?? {});
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument(String docKey, String docTitle) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Text('Upload $docTitle',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1500);
    if (picked == null) return;

    setState(() => _uploading[docKey] = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      if (_providerDocId == null) throw Exception('Provider not found');

      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final ref =
          FirebaseStorage.instance.ref('provider_documents/$uid/$docKey.$ext');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(_providerDocId)
          .update({
        'verificationDocuments.$docKey': {
          'url': url,
          'uploadedAt': FieldValue.serverTimestamp(),
          'status': 'pending_review',
          'fileName': '$docKey.$ext',
        },
        'verificationStatus': 'documents_submitted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document uploaded successfully ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading[docKey] = false);
    }
  }

  Future<void> _viewDocument(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')));
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending_review':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending_review':
        return 'Under Review';
      default:
        return 'Not Uploaded';
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending_review':
        return Icons.pending;
      default:
        return Icons.upload_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Documents & Credentials',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Upload your credentials to get verified. '
                          'Verified providers appear higher in search results '
                          'and receive the verified badge.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Document cards
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dark header
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.folder_outlined,
                              size: 16, color: Colors.white70),
                          const SizedBox(width: 10),
                          const Text('Required Documents',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ]),
                      ),
                      ..._requiredDocs.asMap().entries.map((e) {
                        final index = e.key;
                        final doc = e.value;
                        final docKey = doc['key'] as String;
                        final docData = _documents[docKey] as Map?;
                        final status = docData?['status'] as String?;
                        final hasDoc = docData != null;
                        final isUploading = _uploading[docKey] == true;

                        return Column(children: [
                          if (index > 0)
                            Divider(height: 1, color: Colors.grey.shade100),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: hasDoc
                                      ? _statusColor(status).withOpacity(0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  hasDoc
                                      ? _statusIcon(status)
                                      : doc['icon'] as IconData,
                                  color: hasDoc
                                      ? _statusColor(status)
                                      : Colors.grey[500],
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(doc['title'] as String,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: _statusColor(status),
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 3),
                                    Text(doc['subtitle'] as String,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500])),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      if (hasDoc) ...[
                                        OutlinedButton.icon(
                                          onPressed: () => _viewDocument(
                                              docData!['url'] as String),
                                          icon: const Icon(
                                              Icons.visibility_outlined,
                                              size: 14),
                                          label: const Text('View',
                                              style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.black,
                                            side: const BorderSide(
                                                color: Colors.black),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (status != 'approved')
                                        ElevatedButton.icon(
                                          onPressed: isUploading
                                              ? null
                                              : () => _uploadDocument(docKey,
                                                  doc['title'] as String),
                                          icon: isUploading
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white))
                                              : Icon(
                                                  hasDoc
                                                      ? Icons.refresh
                                                      : Icons.upload_outlined,
                                                  size: 14),
                                          label: Text(
                                              isUploading
                                                  ? 'Uploading...'
                                                  : hasDoc
                                                      ? 'Replace'
                                                      : 'Upload',
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                        ),
                                    ]),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        ]);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
    );
  }
}
