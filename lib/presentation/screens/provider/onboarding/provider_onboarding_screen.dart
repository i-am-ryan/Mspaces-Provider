// lib/presentation/screens/onboarding/provider_onboarding_screen.dart
// For provider app: mspaces_provider

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Address / location
  final _streetCtrl = TextEditingController();
  final _suburbCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;
  bool _locationSet = false;

  // Service area radius
  double _serviceRadiusKm = 20;

  // Notification prefs
  bool _notifBookings = true;
  bool _notifPayments = true;
  bool _notifMessages = true;

  final List<String> _provinces = [
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
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _streetCtrl.text =
              '${place.thoroughfare ?? ''} ${place.subThoroughfare ?? ''}'
                  .trim();
          _suburbCtrl.text = place.subLocality ?? place.locality ?? '';
          _cityCtrl.text = place.locality ?? '';
          _provinceCtrl.text = place.administrativeArea ?? '';
          _postalCtrl.text = place.postalCode ?? '';
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

  Future<void> _saveAndComplete() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // If no GPS coords yet, try to geocode the entered address
      if (_latitude == null && _cityCtrl.text.isNotEmpty) {
        try {
          final query = [
            _streetCtrl.text,
            _suburbCtrl.text,
            _cityCtrl.text,
            _provinceCtrl.text,
            'South Africa'
          ].where((s) => s.isNotEmpty).join(', ');
          final locations = await locationFromAddress(query);
          if (locations.isNotEmpty) {
            _latitude = locations.first.latitude;
            _longitude = locations.first.longitude;
          }
        } catch (_) {}
      }

      // Update users collection
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

      // Also update service_providers collection
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
          'serviceRadiusKm': _serviceRadiusKm,
          'coverageAreas': [
            {
              'city': _cityCtrl.text.trim(),
              'suburb': _suburbCtrl.text.trim(),
              'province': _provinceCtrl.text.trim(),
              'radiusKm': _serviceRadiusKm,
            }
          ],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) context.go('/provider-dashboard');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _next() {
    if (_currentPage < 3) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _saveAndComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              ...List.generate(
                  4,
                  (i) => Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _currentPage
                                ? Colors.black
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
            ]),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/provider-home'),
              child: Text('Skip', style: TextStyle(color: Colors.grey[500])),
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWelcomePage(),
                _buildLocationPage(),
                _buildServiceAreaPage(),
                _buildNotificationsPage(),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
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
                    : Text(_currentPage == 3 ? 'Start Working' : 'Continue',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Page 1: Welcome ────────────────────────────────────────────────────────

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
          'You\'re joining a platform that connects you with clients who need your skills. Let\'s set up your profile to start getting bookings.',
          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.6),
        ),
        const SizedBox(height: 32),
        _featureItem(Icons.location_on_outlined, 'Location-based job matching',
            'Clients near you will find you first'),
        const SizedBox(height: 16),
        _featureItem(Icons.navigation_outlined, 'Navigation & ETA',
            'Built-in navigation helps you get to jobs on time'),
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
          borderRadius: BorderRadius.circular(10),
        ),
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

  // ── Page 2: Location ───────────────────────────────────────────────────────

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const Text('Your Base Location',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'This is your home or business address. Clients will be matched to you based on proximity. Your exact address is never shown — only your service area.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 24),
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
              _isGettingLocation
                  ? 'Getting location...'
                  : 'Use My Current Location',
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
        const SizedBox(height: 20),
        _addressField('Street Address', _streetCtrl, 'e.g. 45 Oak Avenue'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _addressField('Suburb', _suburbCtrl, 'e.g. Randburg')),
          const SizedBox(width: 12),
          Expanded(
              child: _addressField('City', _cityCtrl, 'e.g. Johannesburg')),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _provinces.contains(_provinceCtrl.text)
              ? _provinceCtrl.text
              : null,
          decoration: InputDecoration(
            labelText: 'Province',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
          items: _provinces
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) {
            if (v != null) _provinceCtrl.text = v;
          },
        ),
        const SizedBox(height: 12),
        _addressField('Postal Code', _postalCtrl, 'e.g. 2194',
            keyboardType: TextInputType.number),
        if (_locationSet) ...[
          const SizedBox(height: 16),
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
                child: Text(
                  'GPS location saved! Clients will be matched based on your precise location.',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _addressField(String label, TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
      ),
    );
  }

  // ── Page 3: Service Area ───────────────────────────────────────────────────

  Widget _buildServiceAreaPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const Text('Service Area',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'How far are you willing to travel for jobs? This sets your service radius from your base location.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 32),

        // Radius display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Text(
              '${_serviceRadiusKm.toInt()} km',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              'radius from your location',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ]),
        ),
        const SizedBox(height: 24),

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
        const SizedBox(height: 32),

        // Quick select buttons
        const Text('Quick select:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
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
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
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
                'You\'ll only receive job requests from clients within this radius. You can update this anytime in your profile.',
                style: TextStyle(
                    fontSize: 12, color: Colors.blue.shade700, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Page 4: Notifications ──────────────────────────────────────────────────

  Widget _buildNotificationsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const Text('Notification Preferences',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Stay on top of your work with the right notifications.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
          title: 'Payment Received',
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
