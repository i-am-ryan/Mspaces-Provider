// lib/presentation/screens/provider/services/services_management_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServicesManagementScreen extends StatefulWidget {
  const ServicesManagementScreen({Key? key}) : super(key: key);

  @override
  State<ServicesManagementScreen> createState() =>
      _ServicesManagementScreenState();
}

class _ServicesManagementScreenState extends State<ServicesManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<DocumentSnapshot> get _providerStream =>
      _firestore.collection('service_providers').doc(_uid).snapshots();

  String _categoryOf(dynamic entry) {
    if (entry is String) return entry;
    if (entry is Map) return (entry['category'] ?? '').toString();
    return entry.toString();
  }

  Map<String, dynamic> _serviceMapOf(dynamic entry) {
    if (entry is Map) return Map<String, dynamic>.from(entry);
    return {
      'category': entry.toString(),
      'description': '',
      'callOutFee': 0,
      'hourlyRate': 0,
    };
  }

  Future<void> _saveService(Map<String, dynamic> serviceData) async {
    final doc =
        await _firestore.collection('service_providers').doc(_uid).get();
    final raw = List<dynamic>.from(doc.data()?['services'] ?? []);

    // Remove existing entry for this category
    raw.removeWhere(
        (s) => _categoryOf(s) == serviceData['category'].toString());

    // Add updated entry
    raw.add(serviceData);

    final categories =
        raw.map((s) => _categoryOf(s)).where((c) => c.isNotEmpty).toList();

    await _firestore.collection('service_providers').doc(_uid).update({
      'services': raw,
      'serviceCategories': categories,
      'primaryService': categories.isNotEmpty ? categories.first : '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteService(String category) async {
    final doc =
        await _firestore.collection('service_providers').doc(_uid).get();
    final raw = List<dynamic>.from(doc.data()?['services'] ?? []);
    raw.removeWhere((s) => _categoryOf(s) == category);

    final remainingCats =
        raw.map((s) => _categoryOf(s)).where((c) => c.isNotEmpty).toList();

    await _firestore.collection('service_providers').doc(_uid).update({
      'services': raw,
      'serviceCategories': remainingCats,
      'primaryService': remainingCats.isNotEmpty ? remainingCats.first : '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showServiceEditor({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final categoryCtrl =
        TextEditingController(text: existing?['category']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final callOutCtrl = TextEditingController(
        text: existing?['callOutFee']?.toString() == '0' ||
                existing?['callOutFee'] == null
            ? ''
            : existing!['callOutFee'].toString());
    final hourlyCtrl = TextEditingController(
        text: existing?['hourlyRate']?.toString() == '0' ||
                existing?['hourlyRate'] == null
            ? ''
            : existing!['hourlyRate'].toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                // Handle
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                ),

                Text(isEdit ? 'Edit Service' : 'Add Service',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Set your pricing so clients know what to expect',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),

                // Category
                const Text('Service Name *',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryCtrl,
                  enabled: !isEdit,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Plumbing, Electrical, Painting',
                    prefixIcon: const Icon(Icons.build_outlined),
                    filled: true,
                    fillColor:
                        isEdit ? Colors.grey.shade100 : Colors.grey.shade50,
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
                    disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 16),

                // Pricing section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pricing',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        const Text(
                          'These are shown to clients before booking',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        const SizedBox(height: 16),

                        // Call-out fee
                        Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Call-Out Fee (R)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Charged upfront before you arrive',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.white54),
                                  ),
                                ]),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: callOutCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle:
                                    const TextStyle(color: Colors.white38),
                                prefixText: 'R ',
                                prefixStyle:
                                    const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.2))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.2))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Colors.white, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                isDense: true,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // Hourly rate
                        Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hourly Rate (R/hr)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Used to estimate job cost on site',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.white54),
                                  ),
                                ]),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: hourlyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle:
                                    const TextStyle(color: Colors.white38),
                                prefixText: 'R ',
                                prefixStyle:
                                    const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.2))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.2))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Colors.white, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                isDense: true,
                              ),
                            ),
                          ),
                        ]),
                      ]),
                ),
                const SizedBox(height: 16),

                // Info note
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
                            'After assessing the job on site, you quote the full amount. '
                            'The hourly rate is shown as a guide to clients.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade800,
                                height: 1.4),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(height: 16),

                // Description
                const Text('Description (Optional)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final cat = categoryCtrl.text.trim();
                            if (cat.isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('Please enter a service name'),
                                backgroundColor: Colors.red,
                              ));
                              return;
                            }
                            setSheet(() => isSaving = true);
                            try {
                              await _saveService({
                                'category': cat,
                                'description': descCtrl.text.trim(),
                                'callOutFee':
                                    double.tryParse(callOutCtrl.text.trim()) ??
                                        0,
                                'hourlyRate':
                                    double.tryParse(hourlyCtrl.text.trim()) ??
                                        0,
                                'basePrice':
                                    double.tryParse(callOutCtrl.text.trim()) ??
                                        0,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(isEdit
                                      ? 'Service updated!'
                                      : 'Service added!'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ));
                              }
                            } catch (e) {
                              setSheet(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Failed to save: $e'),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Save Changes' : 'Add Service',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemove(String category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Service'),
        content: Text('Remove "$category" from your services?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteService(category);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _providerStream,
      builder: (context, snap) {
        final prov = snap.data?.data() as Map<String, dynamic>? ?? {};
        final raw = List<dynamic>.from(prov['services'] ?? []);

        // Deduplicate by category
        final seen = <String>{};
        final services = <Map<String, dynamic>>[];
        for (final s in raw) {
          final cat = _categoryOf(s);
          if (cat.isNotEmpty && seen.add(cat)) {
            services.add(_serviceMapOf(s));
          }
        }
        final serviceCategory = prov['serviceCategory'] as String? ?? '';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.black),
            ),
            title: const Text('Manage Services',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                onPressed: () => _showServiceEditor(),
                icon: const Icon(Icons.add, color: Colors.black),
                tooltip: 'Add Service',
              ),
            ],
          ),
          body: snap.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.black))
              : Column(children: [
                  if (serviceCategory.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.category_outlined,
                            size: 18, color: Colors.black54),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Primary Category',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500])),
                              Text(serviceCategory,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ]),
                    ),

                  // Pricing info banner
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap a service to set its call-out fee and hourly rate. '
                          'Clients pay the call-out fee upfront for direct bookings.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade800),
                        ),
                      ),
                    ]),
                  ),

                  Expanded(
                    child: services.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: services.length,
                            itemBuilder: (ctx, i) =>
                                _buildServiceTile(services[i]),
                          ),
                  ),
                ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showServiceEditor(),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
          ),
        );
      },
    );
  }

  Widget _buildServiceTile(Map<String, dynamic> service) {
    final category = service['category']?.toString() ?? '';
    final callOutFee = (service['callOutFee'] as num?)?.toDouble() ?? 0;
    final hourlyRate = (service['hourlyRate'] as num?)?.toDouble() ?? 0;
    final description = service['description']?.toString() ?? '';
    final hasPricing = callOutFee > 0 || hourlyRate > 0;

    return GestureDetector(
      onTap: () => _showServiceEditor(existing: service),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasPricing ? Colors.green.shade200 : const Color(0x1A000000),
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.build_outlined,
                    size: 20, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      if (description.isNotEmpty)
                        Text(description,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      if (!hasPricing)
                        Text('Tap to set pricing',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade600,
                                fontWeight: FontWeight.w500)),
                    ]),
              ),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.black54, size: 20),
                  onPressed: () => _showServiceEditor(existing: service),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red[400], size: 20),
                  onPressed: () => _confirmRemove(category),
                  tooltip: 'Remove',
                ),
              ]),
            ]),
          ),

          // Pricing strip
          if (hasPricing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(13),
                  bottomRight: Radius.circular(13),
                ),
                border: const Border(top: BorderSide(color: Color(0x1A000000))),
              ),
              child: Row(children: [
                if (callOutFee > 0) ...[
                  Icon(Icons.directions_car_outlined,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Call-out: R ${callOutFee.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
                if (callOutFee > 0 && hourlyRate > 0)
                  Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 1,
                      height: 14,
                      color: Colors.grey[300]),
                if (hourlyRate > 0) ...[
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('R ${hourlyRate.toStringAsFixed(0)}/hr',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Pricing set',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(13),
                  bottomRight: Radius.circular(13),
                ),
                border: const Border(top: BorderSide(color: Color(0x1A000000))),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_outlined,
                    size: 14, color: Colors.orange.shade600),
                const SizedBox(width: 6),
                Text('No pricing set — tap to add call-out fee & hourly rate',
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.build_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No services added',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Tap + to add your first service',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showServiceEditor(),
          icon: const Icon(Icons.add, color: Colors.white),
          label:
              const Text('Add Service', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ]),
    );
  }
}
