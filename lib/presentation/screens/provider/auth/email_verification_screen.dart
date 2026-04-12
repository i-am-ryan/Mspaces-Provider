import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({Key? key, required this.email})
      : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isSending = false;
  bool _canResend = false;
  int _resendCountdown = 30;
  Timer? _countdownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sendOtp();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west4')
          .httpsCallable('sendEmailOtp');
      await callable.call();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to send code: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startResendCountdown() {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
    await _sendOtp();
    _startResendCountdown();
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otpValue.length < 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west4')
          .httpsCallable('verifyEmailOtp');
      await callable.call({'otp': _otpValue});

      // Refresh token to get updated emailVerified status
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      // No UserTypeService needed for provider app

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Email verified successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        // Check if onboarding needed
        final uid = FirebaseAuth.instance.currentUser?.uid;
        bool onboardingDone = false;
        if (uid != null) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            onboardingDone =
                doc.data()?['onboardingCompleted'] as bool? ?? false;
            final address = doc.data()?['address'] as Map?;
            if (address?['latitude'] != null) onboardingDone = true;
          } catch (_) {}
        }
        if (!mounted) return;
        if (!onboardingDone) {
          context.go('/provider-onboarding');
        } else {
          context.go('/provider-dashboard');
        }
      }
    } catch (e) {
      final msg = e.toString().contains('incorrect')
          ? 'Incorrect code. Please try again.'
          : e.toString().contains('expired')
              ? 'Code has expired. Please request a new one.'
              : e.toString().contains('attempts')
                  ? 'Too many attempts. Please request a new code.'
                  : 'Verification failed. Please try again.';
      if (mounted) setState(() => _errorMessage = msg);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _onDigitEntered(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all 6 digits entered
    if (_otpValue.length == 6) {
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              const Text('Verify your email',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to\n${widget.email}',
                style: TextStyle(
                    fontSize: 15, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 32),

              // OTP input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                    6,
                    (i) => _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onChanged: (v) => _onDigitEntered(i, v),
                          hasError: _errorMessage != null,
                        )),
              ),

              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: TextStyle(
                              fontSize: 13, color: Colors.red.shade700)),
                    ),
                  ]),
                ),

              const SizedBox(height: 24),

              // Verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Verify Email',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 20),

              // Resend
              Center(
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : _canResend
                        ? GestureDetector(
                            onTap: _resendOtp,
                            child: const Text('Resend code',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline)),
                          )
                        : Text(
                            'Resend code in ${_resendCountdown}s',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Check your spam folder if you don\'t see the email',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasError ? Colors.red.shade50 : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.black, width: 2),
          ),
        ),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}
