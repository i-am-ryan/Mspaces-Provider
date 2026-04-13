// lib/presentation/screens/provider/onboarding/provider_onboarding_screen.dart
// For provider app: mspaces_provider

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const List<String> kServiceCategories = [
  'Appliance Repair',
  'Carpentry and Cabinetry',
  'Cleaning and Hygiene',
  'Driveways and Paving',
  'Drywall and Ceilings',
  'Electrical',
  'Flooring and Tiling',
  'Furniture Restoration & Upholstery',
  'Gas Installation',
  'General Handyman Services',
  'Glazing and Windows',
  'Home Staging',
  'HVAC (Heating, Ventilation, & AirCon)',
  'Interior Decorating',
  'Interior Design',
  'Landscaping and Grounds Maintenance',
  'Lighting Design',
  'Outdoor Structures',
  'Painting and Wall Coverings',
  'Pest Control',
  'Plumbing',
  'Pool and Spa Services',
  'Professional Organising',
  'Roofing and Waterproofing',
  'Security and Automation',
  'Solar and Energy Solutions',
  'Structural and Foundation',
  'Waste Management and Remediation',
  'Window Treatments',
  'Other (Please Specify)',
];

const List<String> kSALanguages = [
  'English',
  'Zulu',
  'Xhosa',
  'Afrikaans',
  'Sotho',
  'Tswana',
  'Tsonga',
  'Venda',
  'Ndebele',
  'Swati',
  'Pedi',
  'Other',
];

// ── Widget ────────────────────────────────────────────────────────────────────

class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  static const int _totalPages = 6;
  bool _isSaving = false;

  // ── Page 1: Location ────────────────────────────────────────────────────────
  final _streetCtrl = TextEditingController();
  final _suburbCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;
  bool _locationSet = false;

  // ── Page 2: Services ────────────────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _selectedServices = {};
  final _otherServiceCtrl = TextEditingController();
  bool _otherSelected = false;

  // ── Page 3: About ───────────────────────────────────────────────────────────
  final _bioCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _certificationCtrl = TextEditingController();
  final List<String> _certifications = [];
  final Set<String> _selectedLanguages = {};

  // ── Page 4: Service Area ────────────────────────────────────────────────────
  double _serviceRadiusKm = 20;

  // ── Page 5: Notifications ───────────────────────────────────────────────────
  bool _notifBookings = true;
  bool _notifPayments = true;
  bool _notifMessages = true;

  final List<String> _provinces = const [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Free State',
    'Northern Cape',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _streetCtrl.dispose();
    _suburbCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _postalCtrl.dispose();
    _otherServiceCtrl.dispose();
    _bioCtrl.dispose();
    _yearsCtrl.dispose();
    _certificationCtrl.dispose();
    super.dispose();
  }

  // ── Page titles (for header context) ─────────────────────────────────────
  static const List<String> _pageTitles = [
    'Welcome',
    'Your Location',
    'Your Services',
    'About You',
    'Service Area',
    'Notifications',
  ];

  // ── Validation ──────────────────────────────────────────────────────────────

  String? _validateCurrentPage() {
    switch (_currentPage) {
      case 1: // Location
        if (_suburbCtrl.text.trim().isEmpty) return 'Please enter your suburb.';
        if (_cityCtrl.text.trim().isEmpty) return 'Please enter your city.';
        if (!_provinces.contains(_provinceCtrl.text.trim()))
          return 'Please select your province.';
        return null;

      case 2: // Services
        if (_selectedServices.isEmpty)
          return 'Please select at least one service you offer.';
        if (_otherSelected && _otherServiceCtrl.text.trim().isEmpty)
          return 'Please describe your "Other" service.';
        return null;

      case 3: // About
        if (_bioCtrl.text.trim().isEmpty)
          return 'Please write a short bio so clients know who you are.';
        if (_yearsCtrl.text.trim().isEmpty)
          return 'Please enter your years of experience.';
        if (_selectedLanguages.isEmpty)
          return 'Please select at least one language you speak.';
        return null;

      default:
        return null;
    }
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Location permission denied. Please enter your address manually.')));
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final province = p.administrativeArea ?? '';
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _streetCtrl.text =
              '${p.thoroughfare ?? ''} ${p.subThoroughfare ?? ''}'.trim();
          _suburbCtrl.text = p.subLocality ?? p.locality ?? '';
          _cityCtrl.text = p.locality ?? '';
          _provinceCtrl.text = _provinces.contains(province) ? province : '';
          _postalCtrl.text = p.postalCode ?? '';
          _locationSet = true;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get location: $e')));
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _geocodeManualAddress() async {
    if (_latitude != null || _cityCtrl.text.trim().isEmpty) return;
    try {
      final query = [
        _streetCtrl.text,
        _suburbCtrl.text,
        _cityCtrl.text,
        _provinceCtrl.text,
        'South Africa',
      ].where((s) => s.isNotEmpty).join(', ');
      final results = await locationFromAddress(query);
      if (results.isNotEmpty) {
        _latitude = results.first.latitude;
        _longitude = results.first.longitude;
      }
    } catch (_) {}
  }

  // ── Pricing bottom sheet ─────────────────────────────────────────────────

  void _showPricingSheet(String categoryKey) {
    final isOther = categoryKey == 'Other (Please Specify)';
    final displayName = isOther && _otherServiceCtrl.text.trim().isNotEmpty
        ? _otherServiceCtrl.text.trim()
        : categoryKey;

    final existing = _selectedServices[categoryKey];
    final callOutCtrl = TextEditingController(
        text: (existing?['callOutFee'] as num? ?? 0) > 0
            ? (existing!['callOutFee'] as num).toStringAsFixed(0)
            : '');
    final hourlyCtrl = TextEditingController(
        text: (existing?['hourlyRate'] as num? ?? 0) > 0
            ? (existing!['hourlyRate'] as num).toStringAsFixed(0)
            : '');
    final descCtrl =
        TextEditingController(text: existing?['description']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Set Pricing',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(displayName,
                  style: TextStyle(fontSize: 15, color: Colors.grey[600])),
              const SizedBox(height: 20),

              // Black pricing card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pricing',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text('These are shown to clients before booking',
                          style:
                              TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Call-Out Fee (R)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: 4),
                                Text('Charged upfront before you arrive',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.white54)),
                              ]),
                        ),
                        const SizedBox(width: 12),
                        _pricingField(callOutCtrl),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Hourly Rate (R/hr)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: 4),
                                Text('Used to estimate job cost on site',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.white54)),
                              ]),
                        ),
                        const SizedBox(width: 12),
                        _pricingField(hourlyCtrl),
                      ]),
                    ]),
              ),
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
                        child: Text(
                          'For direct bookings, clients pay the call-out fee upfront. '
                          'After assessing on site, you quote the full amount.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade800,
                              height: 1.4),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(height: 16),

              const Text('Description (Optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe what this service includes...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.5)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final callOut =
                        double.tryParse(callOutCtrl.text.trim()) ?? 0;
                    final hourly = double.tryParse(hourlyCtrl.text.trim()) ?? 0;
                    final finalCategory =
                        isOther && _otherServiceCtrl.text.trim().isNotEmpty
                            ? _otherServiceCtrl.text.trim()
                            : displayName;
                    setState(() {
                      _selectedServices[categoryKey] = {
                        'category': finalCategory,
                        'description': descCtrl.text.trim(),
                        'callOutFee': callOut,
                        'hourlyRate': hourly,
                        'basePrice': callOut,
                      };
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pricingField(TextEditingController ctrl) => SizedBox(
        width: 110,
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixText: 'R ',
            prefixStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            isDense: true,
          ),
        ),
      );

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _saveAndComplete() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await _geocodeManualAddress();

      final servicesList = _selectedServices.values.map((s) {
        if (s['category'] == 'Other (Please Specify)' &&
            _otherServiceCtrl.text.trim().isNotEmpty) {
          return {...s, 'category': _otherServiceCtrl.text.trim()};
        }
        return Map<String, dynamic>.from(s);
      }).toList();

      final categoryNames =
          servicesList.map((s) => s['category'].toString()).toList();

      final languages = _selectedLanguages.toList();
      final years = int.tryParse(_yearsCtrl.text.trim()) ?? 0;

      // ── users ─────────────────────────────────────────────────────────────
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'address': {
          'street': _streetCtrl.text.trim(),
          'suburb': _suburbCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'province': _provinceCtrl.text.trim(),
          'postalCode': _postalCtrl.text.trim(),
          if (_latitude != null) 'latitude': _latitude,
          if (_longitude != null) 'longitude': _longitude,
        },
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'notificationPreferences': {
          'bookings': _notifBookings,
          'payments': _notifPayments,
          'messages': _notifMessages,
        },
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── service_providers ─────────────────────────────────────────────────
      final spSnap = await FirebaseFirestore.instance
          .collection('service_providers')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (spSnap.docs.isNotEmpty) {
        await spSnap.docs.first.reference.update({
          'location': {
            if (_latitude != null) 'latitude': _latitude,
            if (_longitude != null) 'longitude': _longitude,
            'city': _cityCtrl.text.trim(),
            'suburb': _suburbCtrl.text.trim(),
          },
          if (_latitude != null) 'latitude': _latitude,
          if (_longitude != null) 'longitude': _longitude,
          'serviceRadiusKm': _serviceRadiusKm,
          'services': servicesList,
          'serviceCategories': categoryNames,
          'primaryService': categoryNames.isNotEmpty ? categoryNames.first : '',
          'coverageAreas': [
            {
              'city': _cityCtrl.text.trim(),
              'suburb': _suburbCtrl.text.trim(),
              'province': _provinceCtrl.text.trim(),
              'radiusKm': _serviceRadiusKm,
              if (_latitude != null) 'latitude': _latitude,
              if (_longitude != null) 'longitude': _longitude,
            }
          ],
          // About fields
          'bio': _bioCtrl.text.trim(),
          'yearsExperience': years,
          'certifications': _certifications,
          'languages': languages,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) context.go('/provider-dashboard');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _next() async {
    final error = _validateCurrentPage();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_currentPage == 1) _geocodeManualAddress();
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      await _saveAndComplete();
    }
  }

  void _back() {
    if (_currentPage > 0)
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // ── Scaffold ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 24, 0),
            child: Row(children: [
              if (_currentPage > 0)
                IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: Colors.black,
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Row(
                  children: List.generate(
                      _totalPages,
                      (i) => Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                  right: i < _totalPages - 1 ? 5 : 0),
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= _currentPage
                                    ? Colors.black
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          )),
                ),
              ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWelcomePage(),
                _buildLocationPage(),
                _buildServicesPage(),
                _buildAboutPage(),
                _buildServiceAreaPage(),
                _buildNotificationsPage(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _currentPage == _totalPages - 1
                            ? 'Start Working'
                            : 'Continue',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Page 1: Welcome ─────────────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: Colors.black, borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.handyman, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 32),
        const Text('Welcome to\nMspaces Provider!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(
          "You're joining a platform that connects you with clients who need your skills. Let's set up your profile in a few quick steps.",
          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.6),
        ),
        const SizedBox(height: 32),
        _featureItem(Icons.location_on_outlined, 'Location-based matching',
            'Clients near you will find you first'),
        const SizedBox(height: 16),
        _featureItem(Icons.build_circle_outlined, 'Showcase your services',
            'List everything you offer and set your rates'),
        const SizedBox(height: 16),
        _featureItem(Icons.payments_outlined, 'Fast payments',
            'Get paid directly to your account after job completion'),
      ]),
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
      ),
    ]);
  }

  // ── Page 2: Location ────────────────────────────────────────────────────────

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your Base Location',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Used to match you with nearby clients. Your exact address is never shown — only your service area.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGettingLocation ? null : _getCurrentLocation,
            icon: _isGettingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.my_location, size: 18, color: Colors.white),
            label: Text(
              _isGettingLocation ? 'Getting location…' : 'Get My Location',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_locationSet) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(children: [
              Icon(Icons.gps_fixed, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPS coordinates saved',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700)),
                      Text(
                        '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.green.shade600),
                      ),
                    ]),
              ),
            ]),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or enter manually',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ]),
        ),
        _addressField('Street Address', _streetCtrl, 'e.g. 45 Oak Avenue'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _addressField('Suburb', _suburbCtrl, 'e.g. Ferndale')),
          const SizedBox(width: 12),
          Expanded(
              child: _addressField(
                  'City', _cityCtrl, 'e.g. Midrand, e.g. Johannesburg')),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _provinces.contains(_provinceCtrl.text)
              ? _provinceCtrl.text
              : null,
          decoration: _inputDecoration('Province'),
          hint: const Text('Select province'),
          items: _provinces
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _provinceCtrl.text = v);
          },
        ),
        const SizedBox(height: 12),
        _addressField('Postal Code', _postalCtrl, 'e.g. 2194',
            keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'For best accuracy, use "Get My Location". If you enter manually, we will geocode your address to get coordinates.',
                style: TextStyle(
                    fontSize: 12, color: Colors.blue.shade700, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _addressField(String label, TextEditingController ctrl, String hint,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label).copyWith(hintText: hint),
      );

  // ── Page 3: Services ────────────────────────────────────────────────────────

  Widget _buildServicesPage() {
    final pricingCount = _selectedServices.values
        .where((s) =>
            (s['callOutFee'] as num? ?? 0) > 0 ||
            (s['hourlyRate'] as num? ?? 0) > 0)
        .length;
    final total = _selectedServices.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your Services',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Tap a category to select it and set your pricing. Tap again to edit. Long-press to deselect.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 8),
        if (total > 0)
          Row(children: [
            Text('$total selected',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (pricingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$pricingCount with pricing',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        const SizedBox(height: 16),
        if (_otherSelected) ...[
          TextField(
            controller: _otherServiceCtrl,
            decoration: _inputDecoration('Describe your service')
                .copyWith(hintText: 'e.g. Swimming Pool Construction'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kServiceCategories.map((service) {
            final isOther = service == 'Other (Please Specify)';
            final isSelected = isOther
                ? _otherSelected
                : _selectedServices.containsKey(service);
            final serviceData = _selectedServices[service];
            final hasPricing = isSelected &&
                serviceData != null &&
                ((serviceData['callOutFee'] as num? ?? 0) > 0 ||
                    (serviceData['hourlyRate'] as num? ?? 0) > 0);

            return GestureDetector(
              onTap: () {
                if (isSelected) {
                  if (isOther && _otherServiceCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Please describe your service first, then tap again to set pricing.'),
                      behavior: SnackBarBehavior.floating,
                    ));
                    return;
                  }
                  _showPricingSheet(service);
                } else {
                  if (isOther) {
                    setState(() {
                      _otherSelected = true;
                      _selectedServices[service] = {
                        'category': service,
                        'description': '',
                        'callOutFee': 0.0,
                        'hourlyRate': 0.0,
                        'basePrice': 0.0,
                      };
                    });
                  } else {
                    setState(() {
                      _selectedServices[service] = {
                        'category': service,
                        'description': '',
                        'callOutFee': 0.0,
                        'hourlyRate': 0.0,
                        'basePrice': 0.0,
                      };
                    });
                    Future.microtask(() => _showPricingSheet(service));
                  }
                }
              },
              onLongPress: isSelected
                  ? () => setState(() {
                        _selectedServices.remove(service);
                        if (isOther) {
                          _otherSelected = false;
                          _otherServiceCtrl.clear();
                        }
                      })
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: hasPricing
                        ? Colors.green.shade400
                        : isSelected
                            ? Colors.black
                            : Colors.grey.shade300,
                    width: hasPricing ? 2 : 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (hasPricing)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(Icons.check_circle,
                          size: 13, color: Colors.green.shade300),
                    )
                  else if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  Text(service,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      )),
                  if (hasPricing &&
                      (serviceData!['callOutFee'] as num) > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'R${(serviceData['callOutFee'] as num).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else if (isSelected && !hasPricing) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('+ price',
                          style:
                              TextStyle(fontSize: 10, color: Colors.white70)),
                    ),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (total > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.touch_app_outlined, color: Colors.grey[500], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap a selected service to edit its pricing. Long-press to remove it.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600], height: 1.4),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── Page 4: About ────────────────────────────────────────────────────────────

  Widget _buildAboutPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('About You',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Help clients get to know you before they book. This appears on your public profile.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 24),

        // ── Bio ─────────────────────────────────────────────────────────────
        const Text('Bio *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _bioCtrl,
          maxLines: 5,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText:
                'Tell clients about yourself — your background, what you specialise in, and why they should hire you...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
            contentPadding: const EdgeInsets.all(14),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 20),

        // ── Years of experience ──────────────────────────────────────────────
        const Text('Years of Experience *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _yearsCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('').copyWith(
            hintText: 'e.g. 5',
            prefixIcon: Icon(Icons.work_history_outlined,
                size: 20, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 20),

        // ── Certifications ───────────────────────────────────────────────────
        const Text('Certifications',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Optional — add any relevant qualifications or certifications.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),

        // Existing certification chips
        if (_certifications.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _certifications
                .map((cert) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cert,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _certifications.remove(cert)),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white70),
                        ),
                      ]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
        ],

        // Add certification input
        Row(children: [
          Expanded(
            child: TextField(
              controller: _certificationCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('').copyWith(
                hintText: 'e.g. City & Guilds Electrical, NHBRC Registered',
                prefixIcon: Icon(Icons.workspace_premium_outlined,
                    size: 20, color: Colors.grey[500]),
              ),
              onSubmitted: (_) => _addCertification(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _addCertification,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.black, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // ── Languages ────────────────────────────────────────────────────────
        const Text('Languages Spoken *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Select all languages you can communicate in with clients.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kSALanguages.map((lang) {
            final selected = _selectedLanguages.contains(lang);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _selectedLanguages.remove(lang);
                } else {
                  _selectedLanguages.add(lang);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (selected) ...[
                    const Icon(Icons.check, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                  ],
                  Text(lang,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      )),
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  void _addCertification() {
    final text = _certificationCtrl.text.trim();
    if (text.isEmpty) return;
    if (_certifications.contains(text)) {
      _certificationCtrl.clear();
      return;
    }
    setState(() {
      _certifications.add(text);
      _certificationCtrl.clear();
    });
  }

  // ── Page 5: Service Area ────────────────────────────────────────────────────

  Widget _buildServiceAreaPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Service Area',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'How far are you willing to travel? Only clients within this radius can book you.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
              color: Colors.black, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text('${_serviceRadiusKm.toInt()} km',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.bold)),
            Text('radius from your location',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 20),
        Slider(
          value: _serviceRadiusKm,
          min: 5,
          max: 100,
          divisions: 19,
          activeColor: Colors.black,
          onChanged: (v) => setState(() => _serviceRadiusKm = v),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('5 km', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          Text('100 km',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 24),
        const Text('Quick select:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [10, 20, 30, 50, 75, 100].map((km) {
            final sel = _serviceRadiusKm == km.toDouble();
            return GestureDetector(
              onTap: () => setState(() => _serviceRadiusKm = km.toDouble()),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? Colors.black : Colors.grey.shade300),
                ),
                child: Text('$km km',
                    style: TextStyle(
                      fontSize: 13,
                      color: sel ? Colors.white : Colors.black,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You can update your service radius anytime from your profile settings.',
                style: TextStyle(
                    fontSize: 12, color: Colors.blue.shade700, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Page 6: Notifications ───────────────────────────────────────────────────

  Widget _buildNotificationsPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Notifications',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Stay on top of your work. You can change these in settings at any time.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 32),
        _notifTile(
          icon: Icons.work_outline,
          color: Colors.blue,
          title: 'New Bookings',
          subtitle: 'Get notified when a client books you',
          value: _notifBookings,
          onChanged: (v) => setState(() => _notifBookings = v),
        ),
        const SizedBox(height: 12),
        _notifTile(
          icon: Icons.payments_outlined,
          color: Colors.green,
          title: 'Payments',
          subtitle: 'Notifications when payments are confirmed',
          value: _notifPayments,
          onChanged: (v) => setState(() => _notifPayments = v),
        ),
        const SizedBox(height: 12),
        _notifTile(
          icon: Icons.chat_outlined,
          color: Colors.purple,
          title: 'Messages',
          subtitle: 'Client messages and chat notifications',
          value: _notifMessages,
          onChanged: (v) => setState(() => _notifMessages = v),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.grey[500], size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You'll always receive critical notifications like payment confirmations and booking status updates regardless of these settings.",
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500], height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _notifTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: value ? Colors.black : Colors.grey.shade200, width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? Colors.white.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: value ? Colors.white : color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: value ? Colors.white : Colors.black)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: value ? Colors.white60 : Colors.grey[500])),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: Colors.grey[600],
        ),
      ]),
    );
  }
}
