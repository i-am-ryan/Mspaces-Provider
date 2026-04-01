// lib/presentation/screens/provider/profile/provider_profile_screen.dart

import 'package:mspaces_provider/presentation/widgets/common/report_content_widget.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
  double? _providerLocLat;
  double? _providerLocLng;
  String _providerSuburb = '';
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<DocumentSnapshot>? _providerSub;
  bool _isUploadingPhoto = false;
  int _liveCompletedJobs = 0;
  double _liveRating = 0.0;
  int _totalReviews = 0;
  List<Map<String, dynamic>> _reviews = [];
  StreamSubscription<QuerySnapshot>? _bookingsSub;
  StreamSubscription<QuerySnapshot>? _reviewsSub;

  String get _uid => _auth.currentUser?.uid ?? '';

  String get _fullName => (_providerData['displayName'] ??
          _userData['displayName'] ??
          _auth.currentUser?.displayName ??
          'Provider')
      .toString();

  String get _primaryService => (_providerData['primaryService'] ??
          _providerData['serviceCategory'] ??
          '')
      .toString();

  String? get _profilePhotoUrl => _providerData['profilePhotoUrl'] as String?;

  String get _serviceArea {
    final areas = _providerData['coverageAreas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return '';
    final first = areas.first as Map?;
    final city = first?['city']?.toString() ?? '';
    final prov = first?['province']?.toString() ?? '';
    return [city, prov].where((s) => s.isNotEmpty).join(', ');
  }

  List<String> _getServiceCategories() {
    final cats = _providerData['serviceCategories'] as List<dynamic>? ?? [];
    return cats.map((e) => e.toString()).toList();
  }

  String _getCityFromProvider() {
    final areas = _providerData['coverageAreas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return '';
    return (areas.first as Map?)?['city']?.toString() ?? '';
  }

  String _getSuburbFromProvider() {
    final areas = _providerData['coverageAreas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return '';
    return (areas.first as Map?)?['suburb']?.toString() ?? '';
  }

  String _getProvinceFromProvider() {
    final areas = _providerData['coverageAreas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return '';
    return (areas.first as Map?)?['province']?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _userSub =
        _firestore.collection('users').doc(_uid).snapshots().listen((snap) {
      if (mounted) setState(() => _userData = snap.data() ?? {});
    });
    _providerSub = _firestore
        .collection('service_providers')
        .doc(_uid)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _providerData = snap.data() ?? {});
    });
    _bookingsSub = _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: _uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _liveCompletedJobs = snap.docs.length);
    });
    _reviewsSub = _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        final reviewList = snap.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final comment = data['comment']?.toString() ??
              data['comments']?.toString() ??
              data['review']?.toString() ??
              data['text']?.toString() ??
              '';
          return {'id': d.id, ...data, 'comment': comment};
        }).toList();
        double totalRating = 0;
        for (final r in reviewList) {
          totalRating += (r['rating'] as num?)?.toDouble() ?? 0;
        }
        setState(() {
          _reviews = reviewList;
          _totalReviews = reviewList.length;
          _liveRating =
              reviewList.isEmpty ? 0 : totalRating / reviewList.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _providerSub?.cancel();
    _bookingsSub?.cancel();
    _reviewsSub?.cancel();
    super.dispose();
  }

  // ── Availability toggle ────────────────────────────────────────────────────

  Future<void> _toggleAvailability(bool current) async {
    await _firestore
        .collection('service_providers')
        .doc(_uid)
        .update({'isAvailable': !current});
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child:
                const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.signOut();
      if (mounted) context.go('/provider-login');
    }
  }

  // ── GPS location helper ────────────────────────────────────────────────────

  Future<void> _getLocationAndFill(
    TextEditingController cityController, {
    TextEditingController? suburbController,
  }) async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Location permission denied. Please enable in settings.'),
          ));
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Getting your location...'),
          duration: Duration(seconds: 2),
        ));
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final city = place.locality ?? place.administrativeArea ?? '';
        final suburb = place.subLocality ?? place.locality ?? '';

        cityController.text = city;
        if (suburbController != null) suburbController.text = suburb;

        setState(() {
          _providerLocLat = position.latitude;
          _providerLocLng = position.longitude;
          _providerSuburb = suburb;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  // ── Save profile changes ───────────────────────────────────────────────────

  Future<void> _saveProfileChanges({
    required String bio,
    required String phone,
    required String city,
    required String province,
    String suburb = '',
    double? lat,
    double? lng,
  }) async {
    try {
      await _firestore.collection('service_providers').doc(_uid).update({
        'bio': bio,
        'about': bio,
        'phone': phone,
        'coverageAreas': [
          {
            'city': city,
            'suburb': suburb,
            'province': province,
            if (lat != null) 'latitude': lat,
            if (lng != null) 'longitude': lng,
          }
        ],
        'location': {
          'city': city,
          'suburb': suburb,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(_uid).update({
        'phone': phone,
        'address': {
          'city': city,
          'suburb': suburb,
          'province': province,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        },
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Photo upload ───────────────────────────────────────────────────────────

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('providers/$_uid/profile_photo.jpg');
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();

      await Future.wait([
        _firestore.collection('service_providers').doc(_uid).update({
          'profilePhotoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        _firestore.collection('users').doc(_uid).update({
          'profilePhotoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload photo: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Public profile preview ─────────────────────────────────────────────────

  void _showPublicProfilePreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scroll) {
          final bio =
              (_providerData['bio'] ?? _providerData['about'] ?? '').toString();
          return SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.all(24),
            child: Column(
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
                const Text('Your Public Profile',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('This is what clients and landlords see',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Row(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.black,
                    backgroundImage: (_profilePhotoUrl != null &&
                            _profilePhotoUrl!.isNotEmpty)
                        ? NetworkImage(_profilePhotoUrl!)
                        : null,
                    child:
                        (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                            ? Text(
                                _fullName.isNotEmpty
                                    ? _fullName[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold))
                            : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fullName,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(_primaryService,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14)),
                          Row(children: [
                            const Icon(Icons.star,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${((_providerData['rating'] ?? 0.0) as num).toStringAsFixed(1)} • ${_providerData['totalReviews'] ?? 0} reviews',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                            ),
                          ]),
                        ]),
                  ),
                ]),
                const SizedBox(height: 20),
                if (bio.isNotEmpty) ...[
                  const Text('About',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(bio,
                      style: TextStyle(color: Colors.grey[700], height: 1.5)),
                  const SizedBox(height: 16),
                ],
                const Text('Services',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                const Text('Location',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 6),
                  Text(_serviceArea.isNotEmpty ? _serviceArea : 'Not set',
                      style: TextStyle(color: Colors.grey[700])),
                ]),
                const SizedBox(height: 16),
                const Text('Contact',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.phone, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 6),
                  Text(
                      (_providerData['phone'] ??
                              _userData['phone'] ??
                              'Not set')
                          .toString(),
                      style: TextStyle(color: Colors.grey[700])),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.email, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 6),
                  Text(
                      (_providerData['email'] ??
                              _userData['email'] ??
                              'Not set')
                          .toString(),
                      style: TextStyle(color: Colors.grey[700])),
                ]),
                const SizedBox(height: 24),
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

  // ── Edit profile ───────────────────────────────────────────────────────────

  void _showEditProfileDialog() {
    // Initialise controllers
    final bioCtrl = TextEditingController(
        text:
            (_providerData['bio'] ?? _providerData['about'] ?? '').toString());
    final phoneCtrl = TextEditingController(
        text: (_providerData['phone'] ?? _userData['phone'] ?? '').toString());
    final cityCtrl = TextEditingController(text: _getCityFromProvider());
    final suburbCtrl = TextEditingController(text: _getSuburbFromProvider());

    // Seed class-level lat/lng from saved data if not already set
    _providerLocLat ??=
        (_providerData['location']?['latitude'] as num?)?.toDouble();
    _providerLocLng ??=
        (_providerData['location']?['longitude'] as num?)?.toDouble();

    String selectedProvince = _getProvinceFromProvider();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Edit Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // ── Bio ────────────────────────────────────────────────────────
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

              // ── Phone ──────────────────────────────────────────────────────
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

              // ── City ───────────────────────────────────────────────────────
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
                    onPressed: () => _getLocationAndFill(cityCtrl,
                        suburbController: suburbCtrl),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Tap 📍 to use your current location',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 12),

              // ── Suburb ─────────────────────────────────────────────────────
              TextField(
                controller: suburbCtrl,
                decoration: InputDecoration(
                  labelText: 'Suburb',
                  hintText: 'e.g. Sandton',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              // ── Province ───────────────────────────────────────────────────
              const Text('Province',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx, setLocal) => DropdownButtonFormField<String>(
                  value: selectedProvince.isNotEmpty ? selectedProvince : null,
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
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setLocal(() => selectedProvince = v ?? ''),
                ),
              ),
              const SizedBox(height: 24),

              // ── Save button ────────────────────────────────────────────────
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
                      suburb: suburbCtrl.text.trim(),
                      lat: _providerLocLat,
                      lng: _providerLocLng,
                    );
                  },
                  child: const Text('Save Changes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
    final rating = _liveRating > 0
        ? _liveRating
        : (_providerData['averageRating'] ?? _providerData['rating'] ?? 0.0)
            as num;
    final completedJobs = _liveCompletedJobs > 0
        ? _liveCompletedJobs
        : (_providerData['completedJobs'] ?? _providerData['totalJobs'] ?? 0)
            as int;
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
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
            _buildHeaderSection(email),
            const SizedBox(height: 16),
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
            _buildStats(rating.toDouble(), completedJobs),
            const SizedBox(height: 20),
            _buildAvailabilityCard(isAvailable),
            const SizedBox(height: 20),
            _buildInfoCard('Contact Information', [
              _infoRow(Icons.email_outlined, 'Email', email),
              if (phone.isNotEmpty)
                _infoRow(Icons.phone_outlined, 'Phone', phone),
            ]),
            const SizedBox(height: 16),
            if (bio.isNotEmpty) ...[
              _buildInfoCard('About', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(bio,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ),
              ]),
              const SizedBox(height: 16),
            ],
            if (services.isNotEmpty) ...[
              _buildInfoCard('Services Offered', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: services
                      .map((s) => Chip(
                            label:
                                Text(s, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.grey[100],
                          ))
                      .toList(),
                ),
              ]),
              const SizedBox(height: 16),
            ],
            if (_serviceArea.isNotEmpty) ...[
              _buildInfoCard('Service Area', [
                _infoRow(Icons.location_on_outlined, 'Coverage', _serviceArea),
              ]),
              const SizedBox(height: 16),
            ],
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
            if (_reviews.isNotEmpty) ...[
              _buildReviewsSection(),
              const SizedBox(height: 16),
            ],
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

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _buildHeaderSection(String email) {
    return Column(children: [
      GestureDetector(
        onTap: _pickAndUploadPhoto,
        child: Stack(children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.black,
            backgroundImage:
                (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
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
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: Colors.black, shape: BoxShape.circle),
              child: _isUploadingPhoto
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Text(_fullName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      if (_primaryService.isNotEmpty) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
          child: Text(_primaryService,
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ),
      ],
      const SizedBox(height: 4),
      Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
    ]);
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
          _statItem(Icons.star_rounded, Colors.amber, rating.toStringAsFixed(1),
              'Rating'),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _statItem(Icons.check_circle_outline, Colors.green, '$completedJobs',
              'Completed'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, Color color, String value, String label) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _buildAvailabilityCard(bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade50 : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                isAvailable ? Colors.green.shade200 : const Color(0x1A000000)),
      ),
      child: Row(children: [
        Icon(
          isAvailable ? Icons.circle : Icons.circle_outlined,
          color: isAvailable ? Colors.green : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isAvailable ? 'Available for Jobs' : 'Not Available',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isAvailable ? Colors.green[700] : Colors.grey[700]),
            ),
            Text(
              isAvailable
                  ? 'You will receive new job requests'
                  : 'You will not receive new job requests',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ]),
        ),
        Switch(
          value: isAvailable,
          onChanged: (_) => _toggleAvailability(isAvailable),
          activeColor: Colors.green,
        ),
      ]),
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
              color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scroll) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              const Text('All Reviews',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Row(children: [
                Icon(Icons.star, color: Colors.amber[600], size: 16),
                const SizedBox(width: 4),
                Text(_liveRating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(' · $_totalReviews',
                    style: TextStyle(color: Colors.grey[600])),
              ]),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              itemCount: _reviews.length,
              itemBuilder: (_, i) {
                final review = _reviews[i];
                final clientName = review['clientName']?.toString() ?? 'Client';
                final rating = (review['rating'] as num?)?.toDouble() ?? 0;
                final comment = review['comment']?.toString() ?? '';
                final createdAt = (review['createdAt'] as Timestamp?)?.toDate();
                return _reviewCard(
                    review, clientName, rating, comment, createdAt);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review, String clientName,
      double rating, String comment, DateTime? createdAt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: Text(clientName[0].toUpperCase(),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(clientName,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        size: 14,
                        color: Colors.amber[600],
                      ))),
        ]),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comment,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[700], height: 1.4)),
        ],
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          Text(DateFormat('dd MMM yyyy').format(createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => ReportContentWidget(
              contentType: 'review',
              contentId: review['id']?.toString() ?? '',
              contentPreview: comment,
              reportedUserId: review['clientId']?.toString() ?? '',
              reportedUserName: clientName,
            ).show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flag_outlined, size: 13, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text('Report',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildReviewsSection() {
    return _buildInfoCard('Reviews ($_totalReviews)', [
      Row(children: [
        Icon(Icons.star, color: Colors.amber[600], size: 20),
        const SizedBox(width: 6),
        Text(_liveRating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Text('out of 5 · $_totalReviews review${_totalReviews == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ]),
      const SizedBox(height: 12),
      ..._reviews.take(3).map((review) {
        final clientName = review['clientName']?.toString() ?? 'Client';
        final rating = (review['rating'] as num?)?.toDouble() ?? 0;
        final comment = review['comment']?.toString() ?? '';
        final createdAt = (review['createdAt'] as Timestamp?)?.toDate();
        return _reviewCard(review, clientName, rating, comment, createdAt);
      }),
      if (_reviews.length > 3) ...[
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _showAllReviews,
            child: Text('See all $_totalReviews reviews',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ]);
  }
}
