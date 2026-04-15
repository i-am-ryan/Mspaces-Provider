// lib/presentation/screens/profile/banking_details_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BankingDetailsScreen extends StatefulWidget {
  final bool fromBanner;
  const BankingDetailsScreen({Key? key, this.fromBanner = false})
      : super(key: key);

  @override
  State<BankingDetailsScreen> createState() => _BankingDetailsScreenState();
}

class _BankingDetailsScreenState extends State<BankingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();
  final _accountTypeCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasExisting = false;

  final List<String> _bankList = [
    'ABSA',
    'Capitec Bank',
    'FNB',
    'Nedbank',
    'Standard Bank',
    'African Bank',
    'Bidvest Bank',
    'Discovery Bank',
    'Investec',
    'Mercantile Bank',
    'TymeBank',
    'Other',
  ];

  final List<String> _accountTypes = [
    'Cheque / Current',
    'Savings',
    'Transmission',
    'Credit Card',
  ];

  String? _selectedBank;
  String? _selectedAccountType;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountHolderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _branchCodeCtrl.dispose();
    _accountTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final banking = doc.data()?['bankingDetails'] as Map<String, dynamic>?;
      if (banking != null && banking.isNotEmpty) {
        _hasExisting = true;
        _selectedBank = banking['bankName']?.toString();
        _bankNameCtrl.text = banking['bankName']?.toString() ?? '';
        _accountHolderCtrl.text = banking['accountHolder']?.toString() ?? '';
        _accountNumberCtrl.text = banking['accountNumber']?.toString() ?? '';
        _branchCodeCtrl.text = banking['branchCode']?.toString() ?? '';
        _selectedAccountType = banking['accountType']?.toString();
      }
      // Pre-fill account holder from name
      if (_accountHolderCtrl.text.isEmpty) {
        _accountHolderCtrl.text = doc.data()?['fullName']?.toString() ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'bankingDetails': {
          'bankName': _selectedBank ?? _bankNameCtrl.text.trim(),
          'accountHolder': _accountHolderCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'branchCode': _branchCodeCtrl.text.trim(),
          'accountType': _selectedAccountType ?? 'Cheque / Current',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'hasBankingDetails': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Banking details saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        if (widget.fromBanner) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        title: const Text('Banking Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
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
                                  'Your banking details are used for payouts and refunds. '
                                  'This information is securely stored and never shared.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade700,
                                      height: 1.4),
                                ),
                              ),
                            ]),
                      ),
                      const SizedBox(height: 24),

                      // Bank name
                      _label('Bank Name *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedBank,
                        isExpanded: true,
                        decoration: _inputDec('Select your bank'),
                        items: _bankList
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedBank = v),
                        validator: (v) =>
                            v == null ? 'Please select a bank' : null,
                      ),
                      const SizedBox(height: 16),

                      // Account holder
                      _label('Account Holder Name *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _accountHolderCtrl,
                        decoration: _inputDec('Full name as on bank account'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter account holder name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Account number
                      _label('Account Number *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _accountNumberCtrl,
                        decoration: _inputDec('e.g. 1234567890'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter account number'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Branch code
                      _label('Branch Code *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _branchCodeCtrl,
                        decoration: _inputDec('e.g. 250655'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter branch code'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Account type
                      _label('Account Type *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedAccountType,
                        isExpanded: true,
                        decoration: _inputDec('Select account type'),
                        items: _accountTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedAccountType = v),
                        validator: (v) =>
                            v == null ? 'Please select account type' : null,
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(
                                  _hasExisting
                                      ? 'Update Banking Details'
                                      : 'Save Banking Details',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ]),
              ),
            ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));

  InputDecoration _inputDec(String hint) => InputDecoration(
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
      );
}
