// lib/presentation/screens/provider/jobs/create_quote_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateQuoteScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const CreateQuoteScreen({Key? key, required this.data}) : super(key: key);

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen> {
  final _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Client search
  final _clientSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _clientSelected = false;

  // Quote fields
  final List<Map<String, TextEditingController>> _lineItems = [
    {
      'desc': TextEditingController(),
      'amount': TextEditingController(),
    }
  ];
  final _notesCtrl = TextEditingController();
  final _validDaysCtrl = TextEditingController(text: '7');

  bool _includeVat = false;
  bool _requireDeposit = false;
  double _depositPercent = 50;
  bool _isSending = false;

  late String _bookingId;
  late String _clientId;
  late String _clientName;
  late String _clientEmail;
  late String _category;
  late String _address;
  late String _description;
  late String _providerId;
  late String _providerName;
  String _projectName = '';
  String _projectNumber = '';

  bool get _isStandalone =>
      widget.data['bookingId']?.toString().isEmpty ?? true;

  @override
  void initState() {
    super.initState();
    _bookingId = widget.data['bookingId']?.toString() ?? '';
    _clientId = widget.data['clientId']?.toString() ?? '';
    _clientName = widget.data['clientName']?.toString() ?? '';
    _clientEmail = widget.data['clientEmail']?.toString() ?? '';
    _category = widget.data['category']?.toString() ?? '';
    _address = widget.data['address']?.toString() ?? '';
    _description = widget.data['description']?.toString() ?? '';
    _providerId = widget.data['providerId']?.toString() ?? _uid;
    _providerName = widget.data['providerName']?.toString() ?? '';
    _projectName = widget.data['projectName']?.toString() ?? '';
    _projectNumber = widget.data['projectNumber']?.toString() ?? '';

    _clientSelected = _clientId.isNotEmpty;
    if (_clientSelected) {
      _clientSearchCtrl.text = _clientName;
    }

    if (_category.isNotEmpty) {
      _lineItems[0]['desc']!.text = _category;
    }
  }

  @override
  void dispose() {
    _clientSearchCtrl.dispose();
    for (final item in _lineItems) {
      item['desc']!.dispose();
      item['amount']!.dispose();
    }
    _notesCtrl.dispose();
    _validDaysCtrl.dispose();
    super.dispose();
  }

  String _generateQuoteRef() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'QR-$date-$time';
  }

  Future<void> _searchClients(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      // Search by name
      final nameSnap = await _firestore
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();

      // Search by email
      final emailSnap = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();

      final Map<String, Map<String, dynamic>> results = {};
      for (final doc in [...nameSnap.docs, ...emailSnap.docs]) {
        final data = doc.data();
        // Only include clients (not providers)
        if (data['userType']?.toString() == 'provider') continue;
        results[doc.id] = {'id': doc.id, ...data};
      }

      setState(() {
        _searchResults = results.values.toList();
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  void _selectClient(Map<String, dynamic> client) {
    setState(() {
      _clientId = client['id']?.toString() ?? '';
      _clientName = client['fullName']?.toString() ??
          client['fullName']?.toString() ??
          '';
      _clientEmail = client['email']?.toString() ?? '';
      _clientSearchCtrl.text = _clientName;
      _clientSelected = true;
      _searchResults = [];
    });
  }

  double get _subtotal => _lineItems.fold(
      0, (sum, item) => sum + (double.tryParse(item['amount']!.text) ?? 0));

  double get _vatAmount => _includeVat ? _subtotal * 0.15 : 0;
  double get _total => _subtotal + _vatAmount;
  double get _depositAmount =>
      _requireDeposit ? _total * _depositPercent / 100 : 0;

  Future<void> _sendQuote() async {
    if (!_clientSelected || _clientId.isEmpty) {
      _snack('Please select a client', error: true);
      return;
    }

    final items = _lineItems
        .where((item) =>
            item['desc']!.text.trim().isNotEmpty &&
            item['amount']!.text.trim().isNotEmpty)
        .toList();

    if (items.isEmpty) {
      _snack('Add at least one line item with an amount', error: true);
      return;
    }
    if (_total == 0) {
      _snack('Total cannot be zero', error: true);
      return;
    }

    setState(() => _isSending = true);
    try {
      final lineItemData = items
          .map((item) => {
                'description': item['desc']!.text.trim(),
                'amount': double.tryParse(item['amount']!.text.trim()) ?? 0,
              })
          .toList();

      final validDays = int.tryParse(_validDaysCtrl.text) ?? 7;
      final validUntil = DateTime.now().add(Duration(days: validDays));

      // Get provider name if not set
      String provName = _providerName;
      if (provName.isEmpty) {
        final provDoc =
            await _firestore.collection('service_providers').doc(_uid).get();
        provName = provDoc.data()?['fullName']?.toString() ??
            FirebaseAuth.instance.currentUser?.displayName ??
            '';
      }

      final quoteRef = _firestore.collection('quote_requests').doc();
      final quoteRequestId = _generateQuoteRef();

      await quoteRef.set({
        'quoteRequestId': quoteRequestId,
        'firestoreId': quoteRef.id,
        'bookingId': _bookingId,
        'clientId': _clientId,
        'clientName': _clientName,
        'clientEmail': _clientEmail,
        'providerId': _providerId,
        'providerName': provName,
        'category': _category.isNotEmpty ? _category : 'Service',
        'address': _address,
        'description': _description,
        'projectName': _projectName.isNotEmpty ? _projectName : null,
        'projectNumber': _projectNumber.isNotEmpty ? _projectNumber : null,
        'status': 'quoted',
        'source':
            _bookingId.isNotEmpty ? 'onsite_assessment' : 'provider_initiated',
        'quote': {
          'lineItems': lineItemData,
          'subtotal': _subtotal,
          'vatAmount': _vatAmount,
          'includeVat': _includeVat,
          'total': _total,
          'requireDeposit': _requireDeposit,
          'depositPercent': _depositPercent,
          'depositAmount': _depositAmount,
          'notes': _notesCtrl.text.trim(),
          'validUntil': Timestamp.fromDate(validUntil),
          'quotedAt': FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update original booking if linked
      if (_bookingId.isNotEmpty) {
        await _firestore.collection('bookings').doc(_bookingId).update({
          'onsiteQuoteRequestId': quoteRef.id,
          'onSiteQuoteStatus': 'pending_client_approval',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Notify client
      if (_clientId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(_clientId)
            .collection('notifications')
            .add({
          'title': 'Quote Ready — $quoteRequestId',
          'body':
              '$provName has sent you a quote of R${_total.toStringAsFixed(0)} for ${_category.isNotEmpty ? _category : 'services'}.',
          'type': 'quote_received',
          'quoteRequestId': quoteRef.id,
          'bookingId': _bookingId,
          'amount': _total,
          'read': false,
          'actionRequired': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _snack('Quote $quoteRequestId sent to $_clientName!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) context.pop();
      }
    } catch (e) {
      _snack('Failed to send quote: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Quote',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Client selector
          const Text('Client',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_clientSelected) _buildSelectedClient() else _buildClientSearch(),
          const SizedBox(height: 20),

          // Category (editable if standalone)
          if (_isStandalone || _category.isEmpty) ...[
            const Text('Service Category',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _category = v),
              decoration: InputDecoration(
                hintText: 'e.g. Plumbing, Electrical...',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Icon(Icons.build_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(_category,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          const SizedBox(height: 4),

          // Line items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Line Items',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => setState(() => _lineItems.add({
                      'desc': TextEditingController(),
                      'amount': TextEditingController(),
                    })),
                icon: const Icon(Icons.add, size: 16, color: Colors.black),
                label: const Text('Add', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: _lineItems.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: item['desc'],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Description',
                        hintStyle:
                            TextStyle(fontSize: 12, color: Colors.grey[400]),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: item['amount'],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle:
                            TextStyle(fontSize: 12, color: Colors.grey[400]),
                        border: InputBorder.none,
                        isDense: true,
                        prefixText: 'R ',
                        prefixStyle:
                            TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  if (_lineItems.length > 1)
                    GestureDetector(
                      onTap: () => setState(() => _lineItems.removeAt(i)),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.remove_circle,
                            color: Colors.red[400], size: 18),
                      ),
                    ),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // VAT + Deposit
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: [
              Row(children: [
                Checkbox(
                  value: _includeVat,
                  onChanged: (v) => setState(() => _includeVat = v ?? false),
                  activeColor: Colors.black,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Include VAT (15%)',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          _includeVat
                              ? 'VAT: R ${_vatAmount.toStringAsFixed(2)}'
                              : 'Add 15% VAT to subtotal',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ]),
                ),
              ]),
              Divider(height: 1, color: Colors.grey.shade200),
              Row(children: [
                Checkbox(
                  value: _requireDeposit,
                  onChanged: (v) =>
                      setState(() => _requireDeposit = v ?? false),
                  activeColor: Colors.black,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Require Deposit',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          _requireDeposit
                              ? 'R ${_depositAmount.toStringAsFixed(2)} due upfront'
                              : 'Request upfront deposit',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ]),
                ),
                if (_requireDeposit)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: DropdownButton<double>(
                      value: _depositPercent,
                      isDense: true,
                      underline: const SizedBox(),
                      items: [25.0, 30.0, 50.0, 60.0, 70.0]
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p.toInt()}%',
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _depositPercent = v ?? 50),
                    ),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Total summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Subtotal',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('R ${_subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ]),
              if (_includeVat) ...[
                const SizedBox(height: 6),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('VAT (15%)',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('R ${_vatAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ]),
              ],
              const Divider(color: Colors.white24, height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text('R ${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ]),
              if (_requireDeposit) ...[
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deposit (${_depositPercent.toInt()}%)',
                          style: TextStyle(
                              color: Colors.amber[300], fontSize: 13)),
                      Text('R ${_depositAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Colors.amber[300],
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]),
                const SizedBox(height: 4),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Remaining balance',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      Text('R ${(_total - _depositAmount).toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ]),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // Project fields
          Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => _projectName = v,
                decoration: InputDecoration(
                  labelText: 'Project Name (optional)',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                onChanged: (v) => _projectNumber = v,
                decoration: InputDecoration(
                  labelText: 'Project No. (optional)',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Notes
          const Text('Notes (Optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Scope of work, materials, conditions...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Valid for
          Row(children: [
            const Text('Quote valid for',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _validDaysCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text('days',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ]),
          const SizedBox(height: 32),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Send Quote · R${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildSelectedClient() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          child: Text(
            _clientName.isNotEmpty ? _clientName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_clientName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            if (_clientEmail.isNotEmpty)
              Text(_clientEmail,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() {
            _clientSelected = false;
            _clientId = '';
            _clientName = '';
            _clientEmail = '';
            _clientSearchCtrl.clear();
          }),
          child: const Icon(Icons.close, color: Colors.white60, size: 18),
        ),
      ]),
    );
  }

  Widget _buildClientSearch() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _clientSearchCtrl,
        onChanged: (v) => _searchClients(v),
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black)))
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: const TextStyle(fontSize: 13),
      ),
      if (_searchResults.isNotEmpty) ...[
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
            ],
          ),
          child: Column(
            children: _searchResults.map((client) {
              final name = client['fullName']?.toString() ??
                  client['fullName']?.toString() ??
                  '';
              final email = client['email']?.toString() ?? '';
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[200],
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: email.isNotEmpty
                    ? Text(email,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]))
                    : null,
                onTap: () => _selectClient(client),
              );
            }).toList(),
          ),
        ),
      ],
      if (_clientSearchCtrl.text.isNotEmpty &&
          _searchResults.isEmpty &&
          !_isSearching)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('No clients found',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
    ]);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
