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
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Basic Info
  final _businessNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2: Service Details
  String _selectedCategory = 'Plumbing';
  final _yearsExperienceController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Step 3: Location
  final _streetAddressController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedProvince = 'Gauteng';
  final _postalCodeController = TextEditingController();
  double _serviceRadius = 15.0;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  final List<String> _serviceCategories = [
    'Plumbing',
    'Electrical',
    'Painting',
    'Cleaning',
    'Gardening',
    'HVAC',
    'Carpentry',
    'Locksmith',
    'Pest Control',
    'Roofing',
  ];

  final List<String> _provinces = [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _yearsExperienceController.dispose();
    _descriptionController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _handleRegister();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  bool _validateStep1() {
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _showError('Please fill in all required fields.');
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
    return true;
  }

  Future<void> _handleRegister() async {
    if (!_acceptTerms) {
      _showError('Please accept the terms and conditions.');
      return;
    }

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();
    final businessName = _businessNameController.text.trim();
    final city = _cityController.text.trim();
    final postalCode = _postalCodeController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() => _isLoading = true);

    try {
      UserCredential? cred;
      String? uid;

      // 1. Try to create Firebase Auth user
      try {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        uid = cred.user!.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Auth account exists but Firestore docs may be missing — try sign in
          try {
            cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            uid = cred.user!.uid;
          } catch (_) {
            // Different password — genuinely already registered
            if (mounted) {
              _showError(
                  'An account already exists with this email. Please login instead.');
            }
            return;
          }
        } else {
          rethrow;
        }
      }

      // 2. Update display name
      await FirebaseAuth.instance.currentUser?.updateDisplayName(fullName);

      final firestore = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();

      // 3. Write users/{uid} — merge so it's safe for both new and existing
      await firestore.collection('users').doc(uid).set({
        'displayName': fullName,
        'email': email,
        'phone': phone,
        'userType': 'provider',
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // 4. Write service_providers/{uid} — merge
      await firestore.collection('service_providers').doc(uid).set({
        'displayName': fullName,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'businessName': businessName.isNotEmpty ? businessName : fullName,
        'primaryService': _selectedCategory,
        'serviceCategory': _selectedCategory,
        'serviceCategories': [_selectedCategory],
        'services': [_selectedCategory],
        'yearsExperience': int.tryParse(_yearsExperienceController.text) ?? 0,
        'bio': description,
        'isAvailable': true,
        'coverageAreas': [
          {
            'city': city,
            'province': _selectedProvince,
            'postalCode': postalCode,
          }
        ],
        'serviceRadius': _serviceRadius.toInt(),
        'rating': 0.0,
        'averageRating': 0.0,
        'totalReviews': 0,
        'completedJobs': 0,
        'profilePhotoUrl': '',
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // 5. Send email verification
      try {
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      } catch (_) {}

      // 6. Sign out — user must verify email before accessing the app
      await FirebaseAuth.instance.signOut();

      // 7. Show dialog then send to login
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Verify Your Email'),
            content: const Text(
                'A verification email has been sent to your email address. '
                'Please verify your email before logging in.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () => context.go('/provider-login'),
                child: const Text('Go to Login',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authMessage(e.code));
    } catch (e) {
      debugPrint('REGISTRATION ERROR: ${e.toString()}');
      if (mounted) _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStep(),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 110,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/benjamin-brunner-imEtY2Kpejk-unsplash.jpg',
            fit: BoxFit.cover,
            errorBuilder: (ctx, e, s) => Container(color: Colors.grey[900]),
          ),
          // Dark overlay
          Container(color: const Color(0x73000000)),
          // Header content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_currentStep > 0) {
                      _previousStep();
                    } else {
                      context.pop();
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provider Registration',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        'Step ${_currentStep + 1} of 3',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.build_rounded,
                      size: 24, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Basic Info'),
          _buildStepConnector(0),
          _buildStepIndicator(1, 'Services'),
          _buildStepConnector(1),
          _buildStepIndicator(2, 'Location'),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? Colors.black : Colors.grey[200],
              shape: BoxShape.circle,
              border:
                  isCurrent ? Border.all(color: Colors.black, width: 2) : null,
            ),
            child: Center(
              child: isActive && !isCurrent
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : Colors.grey[600],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: isCurrent ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    return Container(
      height: 2,
      width: 30,
      margin: const EdgeInsets.only(bottom: 20),
      color: _currentStep > step ? Colors.black : Colors.grey[300],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildServiceDetailsStep();
      case 2:
        return _buildLocationStep();
      default:
        return _buildBasicInfoStep();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Basic Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Tell us about you and your business',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 24),
        _buildTextField(
            controller: _businessNameController,
            label: 'Business Name',
            hint: "e.g., John's Plumbing Services",
            icon: Icons.business),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _fullNameController,
            label: 'Full Name',
            hint: 'Your full name',
            icon: Icons.person),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'your@email.com',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '+27 82 123 4567',
            icon: Icons.phone,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create a password',
            icon: Icons.lock,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            )),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm your password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            )),
      ],
    );
  }

  Widget _buildServiceDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Service Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('What services do you offer?',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 24),
        const Text('Primary Service Category',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33000000)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _serviceCategories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(children: [
                          Icon(_getCategoryIcon(c), size: 20),
                          const SizedBox(width: 12),
                          Text(c),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildTextField(
            controller: _yearsExperienceController,
            label: 'Years of Experience',
            hint: 'e.g., 5',
            icon: Icons.work_history,
            keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        const Text('Service Description',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Describe your services, expertise, and what makes you stand out...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x33000000)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x33000000)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business Location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Where are you based?',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 24),
        _buildTextField(
            controller: _streetAddressController,
            label: 'Street Address',
            hint: '123 Main Street',
            icon: Icons.location_on),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _cityController,
            label: 'City',
            hint: 'e.g., Johannesburg',
            icon: Icons.location_city),
        const SizedBox(height: 16),
        const Text('Province',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33000000)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedProvince,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _provinces
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedProvince = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _postalCodeController,
            label: 'Postal Code',
            hint: 'e.g., 2196',
            icon: Icons.markunread_mailbox,
            keyboardType: TextInputType.number),
        const SizedBox(height: 24),
        const Text('Service Radius',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('How far are you willing to travel for jobs?',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _serviceRadius,
                min: 5,
                max: 50,
                divisions: 9,
                activeColor: Colors.black,
                inactiveColor: Colors.grey[300],
                onChanged: (v) => setState(() => _serviceRadius = v),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_serviceRadius.toInt()} km',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Checkbox(
              value: _acceptTerms,
              onChanged: (v) => setState(() => _acceptTerms = v ?? false),
              activeColor: Colors.black,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    children: const [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x33000000)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x33000000)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Previous',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_currentStep == 2 ? 'Complete Registration' : 'Next',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Plumbing':
        return Icons.plumbing;
      case 'Electrical':
        return Icons.electrical_services;
      case 'Painting':
        return Icons.format_paint;
      case 'Cleaning':
        return Icons.cleaning_services;
      case 'Gardening':
        return Icons.grass;
      case 'HVAC':
        return Icons.ac_unit;
      case 'Carpentry':
        return Icons.carpenter;
      case 'Locksmith':
        return Icons.lock;
      case 'Pest Control':
        return Icons.pest_control;
      case 'Roofing':
        return Icons.roofing;
      default:
        return Icons.build;
    }
  }
}
