// lib/presentation/screens/help_support_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'my_tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Ticket form
  final _ticketFormKey = GlobalKey<FormState>();
  final _ticketSubjectCtrl = TextEditingController();
  final _ticketMessageCtrl = TextEditingController();
  String _ticketCategory = 'General';
  bool _isSubmittingTicket = false;
  bool _ticketSubmitted = false;

  // FAQ search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _expandedFaqId;

  static const _supportEmail = 'support.mspaces@matanabba.co.za';
  static const _supportPhone = '+27711744618';
  static const _supportWhatsApp = '+27711744618';
  static const _supportPhoneDisplay = '+27 71 174 4618';

  final List<String> _ticketCategories = [
    'General',
    'Lease Issues',
    'Payment & Invoices',
    'Property Management',
    'Account & Profile',
    'Technical Problem',
    'Service Requests',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ticketSubjectCtrl.dispose();
    _ticketMessageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Contact actions ──────────────────────────────────────────────────────────

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': 'Mspaces Support Request'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(_supportEmail, 'Email address copied');
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: _supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(_supportPhoneDisplay, 'Phone number copied');
    }
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse(
        'https://wa.me/$_supportWhatsApp?text=Hello%20Mspaces%20Support%2C%20I%20need%20help%20with...');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _copyToClipboard(_supportWhatsApp, 'WhatsApp number copied');
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack(message);
  }

  // ── Ticket submission ────────────────────────────────────────────────────────

  Future<void> _submitTicket() async {
    if (!_ticketFormKey.currentState!.validate()) return;
    setState(() => _isSubmittingTicket = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west4')
          .httpsCallable('submitSupportTicket');
      await callable.call({
        'category': _ticketCategory,
        'subject': _ticketSubjectCtrl.text.trim(),
        'message': _ticketMessageCtrl.text.trim(),
      });
      setState(() => _ticketSubmitted = true);
      _ticketSubjectCtrl.clear();
      _ticketMessageCtrl.clear();
    } catch (e) {
      debugPrint('TICKET ERROR: $e');
      _showSnack('Failed to submit ticket: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _isSubmittingTicket = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Help & Support',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: 'FAQ'),
            Tab(
                icon: Icon(Icons.headset_mic_outlined, size: 18),
                text: 'Contact'),
            Tab(
                icon: Icon(Icons.confirmation_number_outlined, size: 18),
                text: 'Ticket'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFaqTab(),
          _buildContactTab(),
          _buildTicketTab(),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1 — FAQ
  // ============================================================================

  Widget _buildFaqTab() {
    final filtered = _faqItems
        .where((f) =>
            _searchQuery.isEmpty ||
            f.question.toLowerCase().contains(_searchQuery) ||
            f.answer.toLowerCase().contains(_searchQuery) ||
            f.category.toLowerCase().contains(_searchQuery))
        .toList();

    // Group by category
    final categories = <String>{};
    for (final f in filtered) categories.add(f.category);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search frequently asked questions...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No results for "$_searchQuery"',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    for (final category in categories) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(category,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.black54)),
                      ),
                      ...filtered
                          .where((f) => f.category == category)
                          .map((f) => _buildFaqTile(f)),
                    ],
                    const SizedBox(height: 16),
                    // Still need help prompt
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(children: [
                        Icon(Icons.help_outline,
                            color: Colors.blue.shade700, size: 28),
                        const SizedBox(height: 8),
                        Text('Still need help?',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800)),
                        const SizedBox(height: 4),
                        Text('Contact our support team or submit a ticket.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue.shade700)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _tabController.animateTo(1),
                              style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.blue.shade400),
                                  foregroundColor: Colors.blue.shade700,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              child: const Text('Contact Us'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _tabController.animateTo(2),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              child: const Text('Submit Ticket',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFaqTile(_FaqItem faq) {
    final isExpanded = _expandedFaqId == faq.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isExpanded ? Colors.black26 : Colors.grey.shade200),
        boxShadow: isExpanded
            ? const [
                BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            setState(() => _expandedFaqId = isExpanded ? null : faq.id),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(faq.question,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isExpanded ? Colors.black : Colors.black87)),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(faq.answer,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, color: Colors.black87)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 2 — CONTACT
  // ============================================================================

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Icon(Icons.support_agent, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              const Text('We\'re here to help',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Our support team is available Monday–Friday, 8am–5pm SAST.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          const Text('Contact Channels',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Email
          _contactCard(
            icon: Icons.email_outlined,
            iconColor: Colors.blue,
            title: 'Email Support',
            subtitle: _supportEmail,
            badge: 'Replies within 24 hours',
            badgeColor: Colors.blue,
            onTap: _launchEmail,
            actionLabel: 'Send Email',
          ),
          const SizedBox(height: 12),

          // Phone
          _contactCard(
            icon: Icons.phone_outlined,
            iconColor: Colors.green,
            title: 'Phone Support',
            subtitle: _supportPhoneDisplay,
            badge: 'Mon–Fri, 8am–5pm',
            badgeColor: Colors.green,
            onTap: _launchPhone,
            actionLabel: 'Call Now',
          ),
          const SizedBox(height: 12),

          // WhatsApp
          _contactCard(
            icon: Icons.chat_outlined,
            iconColor: const Color(0xFF25D366),
            title: 'WhatsApp',
            subtitle: _supportPhoneDisplay,
            badge: 'Fastest response',
            badgeColor: const Color(0xFF25D366),
            onTap: _launchWhatsApp,
            actionLabel: 'Open WhatsApp',
          ),
          const SizedBox(height: 12),

          // Live Chat
          _contactCard(
            icon: Icons.headset_mic_outlined,
            iconColor: Colors.purple,
            title: 'Live Chat',
            subtitle: 'Chat with a support agent in real time',
            badge: 'Coming soon',
            badgeColor: Colors.purple,
            onTap: null,
            actionLabel: 'Coming Soon',
            disabled: true,
          ),
          const SizedBox(height: 24),

          // Business hours
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.access_time_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Business Hours',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 10),
                _hoursRow('Monday – Friday', '08:00 – 17:00'),
                _hoursRow('Saturday', '09:00 – 13:00'),
                _hoursRow('Sunday & Public Holidays', 'Closed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback? onTap,
    required String actionLabel,
    bool disabled = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: disabled
            ? null
            : const [
                BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: disabled ? Colors.grey : Colors.black)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: disabled ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: disabled ? Colors.grey : badgeColor)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: disabled ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: disabled ? Colors.grey.shade200 : Colors.black,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: disabled ? Colors.grey : Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _hoursRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
            width: 180,
            child: Text(day,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
        Text(hours,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ============================================================================
  // TAB 3 — SUBMIT A TICKET
  // ============================================================================

  Widget _buildTicketTab() {
    if (_ticketSubmitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade200, width: 2),
                ),
                child: Icon(Icons.check_circle_outline,
                    size: 44, color: Colors.green.shade600),
              ),
              const SizedBox(height: 20),
              const Text('Ticket Submitted!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Your support ticket has been received. We\'ll respond to $_supportEmail within 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _ticketSubmitted = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Another Ticket',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _ticketFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Describe your issue in detail. We aim to respond within 24 business hours. For urgent issues please call or WhatsApp us.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

// View my tickets button
            if (!_ticketSubmitted) ...[
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('View My Tickets'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
            ],

// Category
            const Text('Category',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _ticketCategory,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _ticketCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _ticketCategory = v);
              },
            ),
            const SizedBox(height: 16),

            // Subject
            const Text('Subject',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ticketSubjectCtrl,
              decoration: InputDecoration(
                hintText: 'Brief description of the issue',
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
                    borderSide:
                        const BorderSide(color: Colors.black, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please enter a subject'
                  : null,
            ),
            const SizedBox(height: 16),

            // Message
            const Text('Message',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ticketMessageCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                hintText:
                    'Please describe your issue in detail. Include any relevant information such as property address, unit number, dates, or error messages.',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
                    borderSide:
                        const BorderSide(color: Colors.black, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please describe your issue';
                }
                if (v.trim().length < 20) {
                  return 'Please provide more detail (at least 20 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingTicket ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmittingTicket
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Ticket',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Tickets are responded to within 24 business hours',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── FAQ data ───────────────────────────────────────────────────────────────────

class _FaqItem {
  final String id;
  final String category;
  final String question;
  final String answer;
  const _FaqItem(
      {required this.id,
      required this.category,
      required this.question,
      required this.answer});
}

const List<_FaqItem> _faqItems = [
  // ── Getting Started ──────────────────────────────────────────────────────────
  _FaqItem(
    id: 'gs1',
    category: 'Getting Started',
    question: 'How do I create an account on Mspaces?',
    answer:
        'Download the Mspaces app and tap "Create Account". Choose your account type — Homeowner, Landlord, or Tenant. Tenants require an invitation code from their landlord. Fill in your details and verify your email address to get started.',
  ),
  _FaqItem(
    id: 'gs2',
    category: 'Getting Started',
    question: 'What is the difference between Landlord and Homeowner accounts?',
    answer:
        'A Landlord account is designed for managing rental properties and tenants — it includes lease management, invoice generation, tenant communication, and service request approval. A Homeowner account is for property owners who use Mspaces primarily to book maintenance and home services. You can switch between these two account types in your profile settings.',
  ),
  _FaqItem(
    id: 'gs3',
    category: 'Getting Started',
    question: 'How do I switch my account type?',
    answer:
        'Go to Profile → Account Type → tap "Change". You can switch between Landlord and Homeowner accounts. Note that Tenant and Service Provider account types cannot be changed this way — contact support if you need to change these.',
  ),

  // ── Tenants ──────────────────────────────────────────────────────────────────
  _FaqItem(
    id: 'tn1',
    category: 'Tenants & Invitations',
    question: 'How do I invite a tenant to my property?',
    answer:
        'From the Landlord Dashboard, go to a property and tap "Add Tenant". Enter the tenant\'s name, email, phone, and the unit details. A unique 6-character invitation code will be generated and emailed to the tenant. The tenant enters this code when signing up.',
  ),
  _FaqItem(
    id: 'tn2',
    category: 'Tenants & Invitations',
    question:
        'The tenant says their invitation code is invalid. What should I do?',
    answer:
        'Invitation codes expire after 7 days. If the code has expired, go to the tenant detail screen and send a new invitation. Also check that the tenant is using the exact email address the invitation was sent to — the email must match. Codes are 6 characters and case-insensitive.',
  ),
  _FaqItem(
    id: 'tn3',
    category: 'Tenants & Invitations',
    question: 'Can a tenant have more than one active lease?',
    answer:
        'Each tenant account is linked to one active tenancy at a time. If a tenant needs to move to a new property, the old lease should be ended first and a new invitation sent for the new property.',
  ),

  // ── Leases ───────────────────────────────────────────────────────────────────
  _FaqItem(
    id: 'ls1',
    category: 'Lease Management',
    question: 'How do I create a lease agreement?',
    answer:
        'From the Tenant Detail screen, tap the Lease tab → Generate New Lease. The 5-step lease builder will guide you through property details, parties, financial terms, clauses, and your signature. Once you sign, the tenant is notified to review and countersign from their device.',
  ),
  _FaqItem(
    id: 'ls2',
    category: 'Lease Management',
    question: 'How does the tenant sign the lease?',
    answer:
        'After the landlord signs, the tenant receives a notification in their app. They open the Lease tab → Sign tab, review all clauses, add their initials, draw their signature, and tap "Sign Lease Agreement". The lease status then updates to "Fully Signed".',
  ),
  _FaqItem(
    id: 'ls3',
    category: 'Lease Management',
    question: 'Can I renew an existing lease?',
    answer:
        'Yes. Go to Tenant Detail → Lease tab → Renew Existing Lease. This opens the lease builder pre-filled with all the existing lease details. The new start date is automatically set to the day after the current lease ends. You only need to confirm or adjust the dates and rent.',
  ),
  _FaqItem(
    id: 'ls4',
    category: 'Lease Management',
    question: 'How do I download a lease as a PDF?',
    answer:
        'On the landlord side, go to Tenant Detail → Lease tab and tap the red PDF icon next to the current lease. On the tenant side, go to My Lease → Current tab and tap the PDF icon. You can save, print, or share the PDF from the standard share sheet.',
  ),

  // ── Invoices ─────────────────────────────────────────────────────────────────
  _FaqItem(
    id: 'inv1',
    category: 'Invoices & Payments',
    question: 'How do I generate a rental invoice for my tenant?',
    answer:
        'Go to Tenant Detail → Invoice tab. Set the invoice date, due date, and confirm the rent amount. Tap "Download" to generate a PDF for yourself, or "Share with Tenant" to send it directly to the tenant with a push notification.',
  ),
  _FaqItem(
    id: 'inv2',
    category: 'Invoices & Payments',
    question: 'How do utility invoices work?',
    answer:
        'Go to Tenant Detail → Utilities tab. Enter the electricity and water meter readings and the amounts from the municipal bill, plus the refuse amount. The app calculates consumption and generates a City of Johannesburg-style utility invoice that can be downloaded or shared with the tenant.',
  ),
  _FaqItem(
    id: 'inv3',
    category: 'Invoices & Payments',
    question: 'Where can I see all past invoices?',
    answer:
        'Past invoices are listed at the bottom of both the Invoice tab and the Utilities tab on the Tenant Detail screen. Each invoice shows the date, amount, and status. You can tap the download icon to retrieve the PDF.',
  ),

  // ── Service Requests ─────────────────────────────────────────────────────────
  _FaqItem(
    id: 'sr1',
    category: 'Service Requests',
    question: 'How does a tenant submit a maintenance request?',
    answer:
        'Tenants tap "Report Issue" or "Service Request" from their home screen. They select a category (plumbing, electrical, etc.), describe the problem, set the urgency level, and optionally attach photos. The landlord receives an instant notification.',
  ),
  _FaqItem(
    id: 'sr2',
    category: 'Service Requests',
    question: 'How do I approve or decline a service request?',
    answer:
        'From the Landlord Dashboard, service requests appear in the Service Requests section. Tap a request to view details, then tap "Approve" or "Review". Approved requests can then be forwarded to a service provider through the Find Provider feature.',
  ),
  _FaqItem(
    id: 'sr3',
    category: 'Service Requests',
    question: 'Can I track the status of a service request?',
    answer:
        'Yes. Service requests show their current status — Pending Approval, Approved, In Progress, or Completed. Both landlords and tenants receive push notifications when the status changes, provided notifications are enabled in their profile settings.',
  ),

  // ── Account ───────────────────────────────────────────────────────────────────
  _FaqItem(
    id: 'ac1',
    category: 'Account & Security',
    question: 'How do I change my password?',
    answer:
        'Go to Profile → Security → Change Password. You\'ll need to enter your current password first for security verification, then enter and confirm your new password. Passwords must be at least 6 characters.',
  ),
  _FaqItem(
    id: 'ac2',
    category: 'Account & Security',
    question: 'How do I update my profile photo?',
    answer:
        'Tap the camera icon on your profile photo at the top of the Profile screen (you don\'t need to be in edit mode). Choose to take a photo or select from your gallery. The photo uploads directly and updates immediately.',
  ),
  _FaqItem(
    id: 'ac3',
    category: 'Account & Security',
    question: 'What happens when I delete my account?',
    answer:
        'Your account is deactivated immediately but all your data is retained for 30 days. During this period you can reactivate your account simply by signing in again with your existing credentials. After 30 days, your data is permanently deleted and cannot be recovered.',
  ),
  _FaqItem(
    id: 'ac4',
    category: 'Account & Security',
    question: 'How do I control which notifications I receive?',
    answer:
        'Go to Profile → Notification Preferences. You can individually toggle lease updates, payment reminders, service request notifications, maintenance alerts, app updates, and promotional messages. Changes take effect immediately.',
  ),

  // ── Technical ────────────────────────────────────────────────────────────────
  _FaqItem(
    id: 'tech1',
    category: 'Technical',
    question: 'The app is not loading my data. What should I do?',
    answer:
        'First check your internet connection. Pull down to refresh on any screen. If the problem persists, try signing out and signing back in. If you still experience issues, submit a support ticket with details of what screen is affected.',
  ),
  _FaqItem(
    id: 'tech2',
    category: 'Technical',
    question: 'I am not receiving push notifications. How do I fix this?',
    answer:
        'Check that notifications are enabled both in your phone\'s system settings for Mspaces, and in the app under Profile → Notification Preferences. Make sure the specific notification type (e.g. lease updates, payment reminders) is toggled on. On iOS, check that you granted notification permission when first installing the app.',
  ),
  _FaqItem(
    id: 'tech3',
    category: 'Technical',
    question: 'How do I report a bug or technical problem?',
    answer:
        'Use the Submit a Ticket tab above and select "Technical Problem" as the category. Please include as much detail as possible — what screen you were on, what you were trying to do, and any error messages you saw. Screenshots are very helpful.',
  ),
];
