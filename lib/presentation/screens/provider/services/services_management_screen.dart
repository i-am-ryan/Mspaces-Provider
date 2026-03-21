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

  // Extract display category string from a service entry (String or Map)
  String _categoryOf(dynamic entry) {
    if (entry is String) return entry;
    if (entry is Map) return (entry['category'] ?? '').toString();
    return entry.toString();
  }

  Future<void> _addService(String category) async {
    await _firestore.collection('service_providers').doc(_uid).update({
      'services': FieldValue.arrayUnion([
        {'category': category, 'description': '', 'basePrice': 0}
      ]),
      'serviceCategories': FieldValue.arrayUnion([category]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteService(String category) async {
    final doc = await _firestore
        .collection('service_providers')
        .doc(_uid)
        .get();

    final raw = List<dynamic>.from(doc.data()?['services'] ?? []);

    // Remove entries matching this category (handles both String and Map)
    raw.removeWhere((s) => _categoryOf(s) == category);

    final remainingCats =
        raw.map((s) => _categoryOf(s)).where((c) => c.isNotEmpty).toList();

    await _firestore.collection('service_providers').doc(_uid).update({
      'services': raw,
      'serviceCategories': remainingCats,
      'primaryService':
          remainingCats.isNotEmpty ? remainingCats.first : '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Service'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Electrical wiring',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) await _addService(val);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(String category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Service'),
        content: Text('Remove "$category" from your services?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteService(category);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
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
        // Deduplicate by category for display
        final seen = <String>{};
        final categories = <String>[];
        for (final s in raw) {
          final cat = _categoryOf(s);
          if (cat.isNotEmpty && seen.add(cat)) categories.add(cat);
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
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, color: Colors.black),
                tooltip: 'Add Service',
              ),
            ],
          ),
          body: snap.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.black))
              : Column(
                  children: [
                    if (serviceCategory.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.category_outlined,
                                size: 20, color: Colors.black54),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Primary Category',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500])),
                                Text(serviceCategory,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: categories.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: categories.length,
                              itemBuilder: (ctx, i) =>
                                  _buildServiceTile(categories[i]),
                            ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddDialog,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
          ),
        );
      },
    );
  }

  Widget _buildServiceTile(String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.build_outlined,
              size: 20, color: Colors.black54),
        ),
        title: Text(category,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red[400]),
          onPressed: () => _confirmRemove(category),
          tooltip: 'Remove',
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No services added',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tap + to add your first service',
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Service',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
