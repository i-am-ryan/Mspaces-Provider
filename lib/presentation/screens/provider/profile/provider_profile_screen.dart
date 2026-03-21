import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _providerData = {};
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<DocumentSnapshot>? _providerSub;

  String get _uid => _auth.currentUser?.uid ?? '';

  String get _fullName =>
      (_providerData['displayName'] ??
              _userData['displayName'] ??
              _auth.currentUser?.displayName ??
              'Provider')
          .toString();

  String get _primaryService =>
      (_providerData['primaryService'] ??
              _providerData['serviceCategory'] ??
              '')
          .toString();

  String? get _profilePhotoUrl =>
      _providerData['profilePhotoUrl'] as String?;

  String get _serviceArea {
    final areas = _providerData['coverageAreas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return '';
    final first = areas.first as Map?;
    final city = first?['city']?.toString() ?? '';
    final prov = first?['province']?.toString() ?? '';
    return [city, prov].where((s) => s.isNotEmpty).join(', ');
  }

  List<String> _getServiceCategories() {
    final cats =
        _providerData['serviceCategories'] as List<dynamic>? ?? [];
    return cats.map((e) => e.toString()).toList();
  }

  String _getCityFromProvider() {
    final areas = _providerData['coverageAreas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return '';
    return (areas.first as Map?)?['city']?.toString() ?? '';
  }

  String _getProvinceFromProvider() {
    final areas = _providerData['coverageAreas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return '';
    return (areas.first as Map?)?['province']?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _userSub = _firestore
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _userData = snap.data() ?? {};
        });
      }
    });
    _providerSub = _firestore
        .collection('service_providers')
        .doc(_uid)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _providerData = snap.data() ?? {};
        });
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _providerSub?.cancel();
    super.dispose();
  }

  // ── Availability toggle ──────────────────────────────────────────────

  Future<void> _toggleAvailability(bool current) async {
    await _firestore
        .collection('service_providers')
        .doc(_uid)
        .update({'isAvailable': !current});
  }

  // ── Sign out ─────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.signOut();
      if (mounted) context.go('/provider-login');
    }
  }

  // ── GPS location helper ──────────────────────────────────────────────

  Future<void> _getLocationAndFill(
      TextEditingController controller) async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission denied. Please enable in settings.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Getting your location...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city = place.locality ??
            place.subLocality ??
            place.administrativeArea ??
            '';
        controller.text = city;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    }
  }

  // ── Save profile changes ─────────────────────────────────────────────

  Future<void> _saveProfileChanges({
    required String bio,
    required String phone,
    required String city,
    required String province,
  }) async {
    try {
      await _firestore.collection('service_providers').doc(_uid).update({
        'bio': bio,
        'about': bio,
        'phone': phone,
        'coverageAreas': [
          {'city': city, 'province': province}
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('users').doc(_uid).update({
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Public profile preview ───────────────────────────────────────────

  void _showPublicProfilePreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scroll) {
          final bio =
              (_providerData['bio'] ?? _providerData['about'] ?? '')
                  .toString();
          return SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
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

              const Text('Your Public Profile',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('This is what clients and landlords see',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),

              // Avatar + name row
              Row(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.black,
                  backgroundImage: (_profilePhotoUrl != null &&
                          _profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(_profilePhotoUrl!)
                      : null,
                  child: (_profilePhotoUrl == null ||
                          _profilePhotoUrl!.isEmpty)
                      ? Text(
                          _fullName.isNotEmpty
                              ? _fullName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fullName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text(_primaryService,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14)),
                      Row(children: [
                        const Icon(Icons.star,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${((_providerData['rating'] ?? 0.0) as num).toStringAsFixed(1)}'
                          ' • ${_providerData['totalReviews'] ?? 0} reviews',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // Bio
              if (bio.isNotEmpty) ...[
                const Text('About',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(bio,
                    style: TextStyle(
                        color: Colors.grey[700], height: 1.5)),
                const SizedBox(height: 16),
              ],

              // Services
              const Text('Services',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _getServiceCategories()
                    .map((cat) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(cat,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Location
              const Text('Location',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.location_on,
                    color: Colors.grey[600], size: 18),
                const SizedBox(width: 6),
                Text(
                  _serviceArea.isNotEmpty ? _serviceArea : 'Not set',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ]),
              const SizedBox(height: 16),

              // Contact
              const Text('Contact',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.phone, color: Colors.grey[600], size: 18),
                const SizedBox(width: 6),
                Text(
                    (_providerData['phone'] ?? _userData['phone'] ?? 'Not set')
                        .toString(),
                    style: TextStyle(color: Colors.grey[700])),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.email, color: Colors.grey[600], size: 18),
                const SizedBox(width: 6),
                Text(
                    (_providerData['email'] ?? _userData['email'] ?? 'Not set')
                        .toString(),
                    style: TextStyle(color: Colors.grey[700])),
              ]),
              const SizedBox(height: 24),

              // Close
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Preview'),
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  // ── Edit profile ─────────────────────────────────────────────────────

  void _showEditProfileDialog() {
    final bioCtrl = TextEditingController(
        text: (_providerData['bio'] ?? _providerData['about'] ?? '')
            .toString());
    final phoneCtrl = TextEditingController(
        text: (_providerData['phone'] ?? _userData['phone'] ?? '')
            .toString());
    final cityCtrl =
        TextEditingController(text: _getCityFromProvider());
    String selectedProvince = _getProvinceFromProvider();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Edit Profile',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Bio
              const Text('About / Bio',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: bioCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tell clients about your experience...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              // Phone
              const Text('Phone Number',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '0XX XXX XXXX',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              // City + GPS
              const Text('City / Location',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Johannesburg',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    onPressed: () => _getLocationAndFill(cityCtrl),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Tap 📍 to use your current location',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 16),

              // Province
              const Text('Province',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx, setLocal) =>
                    DropdownButtonFormField<String>(
                  value:
                      selectedProvince.isNotEmpty ? selectedProvince : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  hint: const Text('Select province'),
                  items: [
                    'Gauteng',
                    'Western Cape',
                    'KwaZulu-Natal',
                    'Eastern Cape',
                    'Limpopo',
                    'Mpumalanga',
                    'North West',
                    'Free State',
                    'Northern Cape',
                  ]
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) =>
                      setLocal(() => selectedProvince = v ?? ''),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveProfileChanges(
                      bio: bioCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      city: cityCtrl.text.trim(),
                      province: selectedProvince,
                    );
                  },
                  child: const Text('Save Changes',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final email = (_userData['email'] ??
            _providerData['email'] ??
            _auth.currentUser?.email ??
            '')
        .toString();
    final phone =
        (_providerData['phone'] ?? _userData['phone'] ?? '').toString();
    final bio =
        (_providerData['bio'] ?? _providerData['about'] ?? '').toString();
    final rating = (_providerData['averageRating'] ??
        _providerData['rating'] ??
        0.0) as num;
    final completedJobs = (_providerData['completedJobs'] ??
        _providerData['totalJobs'] ??
        0) as int;
    final isAvailable = _providerData['isAvailable'] as bool? ?? false;
    final services = _getServiceCategories();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text('Profile',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.black),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Avatar & name ──────────────────────────────────────
            _buildHeaderSection(email),
            const SizedBox(height: 16),

            // ── Action buttons ─────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview'),
                  onPressed: _showPublicProfilePreview,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                  onPressed: _showEditProfileDialog,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Stats ──────────────────────────────────────────────
            _buildStats(rating.toDouble(), completedJobs),
            const SizedBox(height: 20),

            // ── Availability ───────────────────────────────────────
            _buildAvailabilityCard(isAvailable),
            const SizedBox(height: 20),

            // ── Contact info ───────────────────────────────────────
            _buildInfoCard('Contact Information', [
              _infoRow(Icons.email_outlined, 'Email', email),
              if (phone.isNotEmpty)
                _infoRow(Icons.phone_outlined, 'Phone', phone),
            ]),
            const SizedBox(height: 16),

            // ── Bio ────────────────────────────────────────────────
            if (bio.isNotEmpty) ...[
              _buildInfoCard('About', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(bio,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700])),
                ),
              ]),
              const SizedBox(height: 16),
            ],

            // ── Services ───────────────────────────────────────────
            if (services.isNotEmpty) ...[
              _buildInfoCard('Services Offered', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: services
                      .map((s) => Chip(
                            label: Text(s,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.grey[100],
                          ))
                      .toList(),
                ),
              ]),
              const SizedBox(height: 16),
            ],

            // ── Location ───────────────────────────────────────────
            if (_serviceArea.isNotEmpty) ...[
              _buildInfoCard('Service Area', [
                _infoRow(Icons.location_on_outlined,
                    'Coverage', _serviceArea),
              ]),
              const SizedBox(height: 16),
            ],

            // ── Manage services ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/provider-services'),
                icon: const Icon(Icons.build_outlined, color: Colors.black),
                label: const Text('Manage Services',
                    style: TextStyle(color: Colors.black)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Sign out ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Sign Out',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ───────────────────────────────────────────────────

  Widget _buildHeaderSection(String email) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.black,
          backgroundImage: (_profilePhotoUrl != null &&
                  _profilePhotoUrl!.isNotEmpty)
              ? NetworkImage(_profilePhotoUrl!)
              : null,
          child: (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
              ? Text(
                  _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(_fullName,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold)),
        if (_primaryService.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_primaryService,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[700])),
          ),
        ],
        const SizedBox(height: 4),
        Text(email,
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStats(double rating, int completedJobs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.star_rounded, Colors.amber,
              rating.toStringAsFixed(1), 'Rating'),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _statItem(Icons.check_circle_outline, Colors.green,
              '$completedJobs', 'Completed'),
        ],
      ),
    );
  }

  Widget _statItem(
      IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAvailabilityCard(bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade50 : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isAvailable
                ? Colors.green.shade200
                : const Color(0x1A000000)),
      ),
      child: Row(
        children: [
          Icon(
            isAvailable ? Icons.circle : Icons.circle_outlined,
            color: isAvailable ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable
                      ? 'Available for Jobs'
                      : 'Not Available',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isAvailable
                          ? Colors.green[700]
                          : Colors.grey[700]),
                ),
                Text(
                  isAvailable
                      ? 'You will receive new job requests'
                      : 'You will not receive new job requests',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            onChanged: (_) => _toggleAvailability(isAvailable),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
