// lib/presentation/screens/provider/auth/provider_register_screen.dart
// Credentials only — services, location, and radius are collected in onboarding.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({Key? key}) : super(key: key);

  @override
  State<ProviderRegisterScreen> createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  bool _isLoading = false;

  final _businessNameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  bool _validate() {
    final name = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _showError('Please fill in all required fields.');
      return false;
    }
    if (!email.contains('@')) {
      _showError('Please enter a valid email address.');
      return false;
    }
    if (pass.length < 6) {
      _showError('Password must be at least 6 characters.');
      return false;
    }
    if (pass != confirm) {
      _showError('Passwords do not match.');
      return false;
    }
    if (!_acceptTerms) {
      _showError('Please accept the Terms of Service and Privacy Policy.');
      return false;
    }
    return true;
  }

  // ── Register ────────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!_validate()) return;

    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final phone = _phoneCtrl.text.trim();
    final businessName = _businessNameCtrl.text.trim();

    setState(() => _isLoading = true);

    try {
      String? uid;

      // 1. Create Firebase Auth user (or recover if Auth exists but Firestore missing)
      try {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        uid = cred.user!.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          try {
            final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            uid = cred.user!.uid;
          } catch (_) {
            _showError(
                'An account already exists with this email. Please log in instead.');
            return;
          }
        } else {
          rethrow;
        }
      }

      // 2. Set display name
      await FirebaseAuth.instance.currentUser?.updateDisplayName(fullName);

      final now = FieldValue.serverTimestamp();

      // 3. users/{uid} — minimal record; onboarding fills address + prefs
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': fullName,
        'email': email,
        'phone': phone,
        'userType': 'provider',
        'onboardingCompleted': false, // ← onboarding sets this to true
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // 4. service_providers/{uid} — skeleton record; onboarding fills the rest
      await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(uid)
          .set({
        'userId': uid,
        'displayName': fullName,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'businessName': businessName.isNotEmpty ? businessName : fullName,
        'isAvailable': true,
        'rating': 0.0,
        'averageRating': 0.0,
        'totalReviews': 0,
        'completedJobs': 0,
        'profilePhotoUrl': '',
        // These will be populated by onboarding:
        'services': [],
        'serviceCategories': [],
        'primaryService': '',
        'serviceRadiusKm': 0,
        'coverageAreas': [],
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // 5. Send to OTP email verification → then onboarding
      if (mounted) {
        context.go('/email-verification', extra: {'email': email});
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authMessage(e.code));
    } catch (e) {
      debugPrint('REGISTRATION ERROR: $e');
      _showError('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _authMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create your account',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      "You'll set up your services and location in the next step.",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 28),

                    // Business name (optional)
                    _field(
                      ctrl: _businessNameCtrl,
                      label: 'Business Name (optional)',
                      hint: "e.g. John's Plumbing Services",
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Full name
                    _field(
                      ctrl: _fullNameCtrl,
                      label: 'Full Name *',
                      hint: 'Your full name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _field(
                      ctrl: _emailCtrl,
                      label: 'Email Address *',
                      hint: 'your@email.com',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    _field(
                      ctrl: _phoneCtrl,
                      label: 'Phone Number *',
                      hint: '+27 82 123 4567',
                      icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _field(
                      ctrl: _passwordCtrl,
                      label: 'Password *',
                      hint: 'At least 6 characters',
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm password
                    _field(
                      ctrl: _confirmPasswordCtrl,
                      label: 'Confirm Password *',
                      hint: 'Repeat your password',
                      icon: Icons.lock_outline,
                      obscure: _obscureConfirmPassword,
                      suffix: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terms
                    GestureDetector(
                      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptTerms,
                                onChanged: (v) =>
                                    setState(() => _acceptTerms = v ?? false),
                                activeColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[700]),
                                  children: const [
                                    TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black),
                                    ),
                                    TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 28),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Create Account',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Already have account
                    Center(
                      child: GestureDetector(
                        onTap: () => context.go('/provider-login'),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                            children: const [
                              TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return SizedBox(
      height: 110,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(
          'assets/images/benjamin-brunner-imEtY2Kpejk-unsplash.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
        ),
        Container(color: const Color(0x73000000)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Provider Registration',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.build_rounded,
                  size: 24, color: Colors.black),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Reusable field ──────────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    ]);
  }
}
