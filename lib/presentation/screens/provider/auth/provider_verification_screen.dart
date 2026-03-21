import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderVerificationScreen extends StatefulWidget {
  const ProviderVerificationScreen({Key? key}) : super(key: key);

  @override
  State<ProviderVerificationScreen> createState() =>
      _ProviderVerificationScreenState();
}

class _ProviderVerificationScreenState
    extends State<ProviderVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  bool _emailVerified = false;
  Timer? _pollTimer;

  // Document upload state (kept for existing UX)
  bool _idUploaded = false;
  bool _businessRegUploaded = false;
  bool _certificationUploaded = false;
  bool _insuranceUploaded = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!_emailVerified) {
      // Poll every 5 seconds so the UI updates automatically
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        await _checkVerification(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (!silent) setState(() => _isChecking = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (mounted) {
        setState(() => _emailVerified = verified);
        if (verified) {
          _pollTimer?.cancel();
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified! Welcome aboard.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email not verified yet. Check your inbox.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (_) {
      // ignore reload errors
    } finally {
      if (mounted && !silent) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent. Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Could not resend email.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _uploadDocument(String type) {
    setState(() {
      switch (type) {
        case 'id':
          _idUploaded = true;
          break;
        case 'business':
          _businessRegUploaded = true;
          break;
        case 'certification':
          _certificationUploaded = true;
          break;
        case 'insurance':
          _insuranceUploaded = true;
          break;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type document uploaded successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _proceed() {
    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email before continuing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_idUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your ID document'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog();
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 60, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text('Verification Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Your documents have been submitted for review. '
              'This usually takes 1–2 business days.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
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
                child: const Text('Go to Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text('Verification',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Email Verification Banner ──────────────────────
              _buildEmailVerificationBanner(),
              const SizedBox(height: 24),

              // ── Document header ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.verified_user,
                          color: Colors.blue[700], size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Get Verified',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Upload your documents to start receiving jobs',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildProgressSection(),
              const SizedBox(height: 24),

              const Text('Required Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _buildDocumentCard(
                title: 'ID Document',
                description: 'South African ID or Passport',
                icon: Icons.badge,
                isRequired: true,
                isUploaded: _idUploaded,
                onUpload: () => _uploadDocument('id'),
              ),
              const SizedBox(height: 16),

              const Text('Optional Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('These help build trust with clients',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 16),

              _buildDocumentCard(
                title: 'Business Registration',
                description: 'CIPC or Company Registration',
                icon: Icons.business,
                isRequired: false,
                isUploaded: _businessRegUploaded,
                onUpload: () => _uploadDocument('business'),
              ),
              _buildDocumentCard(
                title: 'Professional Certifications',
                description: 'Trade certificates, licenses',
                icon: Icons.workspace_premium,
                isRequired: false,
                isUploaded: _certificationUploaded,
                onUpload: () => _uploadDocument('certification'),
              ),
              _buildDocumentCard(
                title: 'Insurance Certificate',
                description: 'Liability or professional insurance',
                icon: Icons.security,
                isRequired: false,
                isUploaded: _insuranceUploaded,
                onUpload: () => _uploadDocument('insurance'),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Submit for Verification',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => context.go('/provider-dashboard'),
                  child: const Text('Skip for now',
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Email verification card shown at the top of the screen.
  Widget _buildEmailVerificationBanner() {
    if (_emailVerified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email Verified',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green)),
                  SizedBox(height: 2),
                  Text('Your email address has been verified.',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_unread, color: Colors.orange[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verify Your Email',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.orange[700])),
                    const SizedBox(height: 2),
                    Text('A link was sent to $email',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isChecking ? null : () => _checkVerification(),
                  icon: _isChecking
                      ? const SizedBox(
                          height: 14, width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text("I've Verified"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isResending ? null : _resendVerification,
                  icon: _isResending
                      ? const SizedBox(
                          height: 14, width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, size: 16),
                  label: const Text('Resend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    int uploadedCount = [
      _idUploaded, _businessRegUploaded,
      _certificationUploaded, _insuranceUploaded
    ].where((b) => b).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upload Progress',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('$uploadedCount of 4 documents',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: uploadedCount / 4,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                uploadedCount == 4 ? Colors.green : Colors.black,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isRequired,
    required bool isUploaded,
    required VoidCallback onUpload,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? Colors.green : const Color(0x1A000000),
          width: isUploaded ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUploaded ? null : onUpload,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUploaded ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUploaded ? Icons.check_circle : icon,
                    color: isUploaded ? Colors.green : Colors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          if (isRequired) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Required',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(description,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Icon(
                  isUploaded ? Icons.check : Icons.upload_file,
                  color: isUploaded ? Colors.green : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
