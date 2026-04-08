// lib/presentation/widgets/common/offers_carousel.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OffersCarousel extends StatelessWidget {
  /// 'all', 'clients', 'providers', 'tenants'
  final String targetType;

  const OffersCarousel({Key? key, this.targetType = 'all'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = Timestamp.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Filter by target type
          final target = data['targetType']?.toString() ?? 'all';
          if (target != 'all' && target != targetType && targetType != 'all') {
            return false;
          }
          // Filter by date
          final end = data['endDate'] as Timestamp?;
          final start = data['startDate'] as Timestamp?;
          if (end != null && end.compareTo(now) < 0) return false;
          if (start != null && start.compareTo(now) > 0) return false;
          return true;
        }).toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Offers & Promotions',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${docs.length} active',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: docs.length,
              itemBuilder: (_, i) => _OfferCard(
                doc: docs[i],
                targetType: targetType,
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _OfferCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String targetType;
  const _OfferCard({required this.doc, required this.targetType});

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  Timer? _impressionTimer;
  bool _impressionLogged = false;

  @override
  void initState() {
    super.initState();
    // Start 3s impression timer
    _impressionTimer = Timer(const Duration(seconds: 3), _logImpression);
  }

  @override
  void dispose() {
    _impressionTimer?.cancel();
    super.dispose();
  }

  Future<void> _logImpression() async {
    if (_impressionLogged) return;
    _impressionLogged = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final date = DateTime.now();
      final key = '${uid}_${date.year}${date.month}${date.day}';
      await FirebaseFirestore.instance
          .collection('offer_analytics')
          .doc(widget.doc.id)
          .collection('impressions')
          .doc(key)
          .set({
        'userId': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'date': '${date.year}-${date.month}-${date.day}',
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _logClick() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('offer_analytics')
          .doc(widget.doc.id)
          .collection('clicks')
          .add({
        'userId': uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _openUrl(String url) async {
    await _logClick();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final imageUrl = data['imageUrl']?.toString();
    final title = data['title']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final discount = data['discountPercent'] ?? 0;
    final target = data['targetType']?.toString() ?? 'all';
    final endDate = data['endDate'] as Timestamp?;
    final ctaUrl = data['ctaUrl']?.toString();
    final ctaLabel = data['ctaLabel']?.toString() ?? 'Learn More';

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.5), BlendMode.darken),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top badges
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$discount% OFF',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(target == 'all' ? 'Everyone' : target,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ]),

              // Bottom content
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        height: 1.4)),
                if (endDate != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.timer_outlined,
                        size: 11, color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      'Ends ${endDate.toDate().day}/${endDate.toDate().month}/${endDate.toDate().year}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11),
                    ),
                  ]),
                ],
                if (ctaUrl != null && ctaUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _openUrl(ctaUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(ctaLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    ),
                  ),
                ],
              ]),
            ]),
      ),
    );
  }
}
