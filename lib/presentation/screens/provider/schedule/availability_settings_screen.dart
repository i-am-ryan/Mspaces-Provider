// lib/presentation/screens/provider/schedule/availability_settings_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AvailabilitySettingsScreen extends StatefulWidget {
  const AvailabilitySettingsScreen({Key? key}) : super(key: key);

  @override
  State<AvailabilitySettingsScreen> createState() =>
      _AvailabilitySettingsScreenState();
}

class _AvailabilitySettingsScreenState
    extends State<AvailabilitySettingsScreen> {
  bool _isAvailable = true;
  bool _autoAccept = false;
  int _maxJobsPerDay = 5;
  int _bufferTime = 30;
  bool _isLoading = true;
  bool _isSaving = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final Map<String, Map<String, dynamic>> _weeklySchedule = {
    'Monday': {'enabled': true, 'start': '08:00', 'end': '18:00'},
    'Tuesday': {'enabled': true, 'start': '08:00', 'end': '18:00'},
    'Wednesday': {'enabled': true, 'start': '08:00', 'end': '18:00'},
    'Thursday': {'enabled': true, 'start': '08:00', 'end': '18:00'},
    'Friday': {'enabled': true, 'start': '08:00', 'end': '17:00'},
    'Saturday': {'enabled': true, 'start': '09:00', 'end': '14:00'},
    'Sunday': {'enabled': false, 'start': '09:00', 'end': '14:00'},
  };

  final List<Map<String, dynamic>> _blockedDates = [];

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(_uid)
          .get();

      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;
      final availability = data['availability'] as Map<String, dynamic>?;

      if (availability != null) {
        setState(() {
          _isAvailable = data['isAvailable'] as bool? ?? true;
          _autoAccept = availability['autoAccept'] as bool? ?? false;
          _maxJobsPerDay =
              (availability['maxJobsPerDay'] as num?)?.toInt() ?? 5;
          _bufferTime = (availability['bufferTime'] as num?)?.toInt() ?? 30;

          final schedule =
              availability['weeklySchedule'] as Map<String, dynamic>?;
          if (schedule != null) {
            for (final day in _weeklySchedule.keys) {
              final dayKey = day.toLowerCase();
              if (schedule.containsKey(dayKey)) {
                final dayData = schedule[dayKey] as Map<String, dynamic>;
                _weeklySchedule[day] = {
                  'enabled': dayData['available'] as bool? ?? true,
                  'start': dayData['start']?.toString() ?? '08:00',
                  'end': dayData['end']?.toString() ?? '17:00',
                };
              }
            }
          }

          final blocked = availability['blockedDates'] as List?;
          if (blocked != null) {
            _blockedDates.clear();
            _blockedDates.addAll(blocked
                .map((b) => Map<String, dynamic>.from(b as Map))
                .toList());
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading availability: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToFirestore() async {
    setState(() => _isSaving = true);
    try {
      // Build weekly schedule in Firestore format
      final weeklySchedule = <String, dynamic>{};
      for (final entry in _weeklySchedule.entries) {
        final dayKey = entry.key.toLowerCase();
        weeklySchedule[dayKey] = {
          'available': entry.value['enabled'] as bool,
          'start': entry.value['start'] as String,
          'end': entry.value['end'] as String,
        };
      }

      await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(_uid)
          .update({
        'isAvailable': _isAvailable,
        'availability': {
          'autoAccept': _autoAccept,
          'maxJobsPerDay': _maxJobsPerDay,
          'bufferTime': _bufferTime,
          'weeklySchedule': weeklySchedule,
          'blockedDates': _blockedDates,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Availability saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text('Availability Settings',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isSaving ? null : _saveToFirestore,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvailabilityToggle(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Weekly Schedule'),
                  _buildWeeklySchedule(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Job Settings'),
                  _buildJobSettings(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Blocked Dates'),
                  _buildBlockedDates(),
                  const SizedBox(height: 32),
                  // Save button at bottom too
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveToFirestore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey.shade300,
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
                            : const Text('Save Availability',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isAvailable ? Colors.green : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isAvailable ? Icons.check_circle : Icons.pause_circle,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _isAvailable ? 'Available for Jobs' : 'Not Available',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              _isAvailable
                  ? 'You will receive new job requests'
                  : 'You won\'t receive new job requests',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ]),
        ),
        Switch(
          value: _isAvailable,
          onChanged: (value) => setState(() => _isAvailable = value),
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withValues(alpha: 0.3),
        ),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildWeeklySchedule() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: _weeklySchedule.entries.map((entry) {
          final day = entry.key;
          final schedule = entry.value;
          final isEnabled = schedule['enabled'] as bool;
          final isLast = day == 'Sunday';

          return Column(children: [
            InkWell(
              onTap: () => _showDayScheduleEditor(day, schedule),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Switch(
                    value: isEnabled,
                    onChanged: (value) => setState(
                        () => _weeklySchedule[day]!['enabled'] = value),
                    activeColor: Colors.black,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(day,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isEnabled ? Colors.black : Colors.grey)),
                  ),
                  if (isEnabled)
                    Text('${schedule['start']} – ${schedule['end']}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]))
                  else
                    Text('Unavailable',
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[400])),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ]),
              ),
            ),
            if (!isLast) Divider(height: 1, color: Colors.grey[200]),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildJobSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.flash_on, color: Colors.blue[700], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Auto-Accept Jobs',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    Text('Automatically accept matching jobs',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
            ),
            Switch(
              value: _autoAccept,
              onChanged: (v) => setState(() => _autoAccept = v),
              activeColor: Colors.black,
            ),
          ]),
        ),
        Divider(height: 1, color: Colors.grey[200]),
        InkWell(
          onTap: _showMaxJobsPicker,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.work_outline,
                    color: Colors.orange[700], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Max Jobs Per Day',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      Text('Limit daily job requests',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ]),
              ),
              Text('$_maxJobsPerDay jobs',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ]),
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),
        InkWell(
          onTap: _showBufferTimePicker,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.timer, color: Colors.purple[700], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Buffer Time Between Jobs',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      Text('Travel time between appointments',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ]),
              ),
              Text('$_bufferTime mins',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBlockedDates() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(children: [
        InkWell(
          onTap: _showAddBlockedDatePicker,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Add Blocked Date',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600])),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        ..._blockedDates.map((blocked) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.block, color: Colors.red[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(blocked['date']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(blocked['reason']?.toString() ?? '',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ]),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _blockedDates.remove(blocked)),
                  icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
                ),
              ]),
            )),
      ]),
    );
  }

  void _showDayScheduleEditor(String day, Map<String, dynamic> schedule) {
    String startTime = schedule['start'] as String;
    String endTime = schedule['end'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Text('$day Schedule',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const Text('Start Time',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                        hour: int.parse(startTime.split(':')[0]),
                        minute: int.parse(startTime.split(':')[1]),
                      ),
                    );
                    if (time != null) {
                      setModal(() {
                        startTime =
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 12),
                      Text(startTime,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('End Time',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                        hour: int.parse(endTime.split(':')[0]),
                        minute: int.parse(endTime.split(':')[1]),
                      ),
                    );
                    if (time != null) {
                      setModal(() {
                        endTime =
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 12),
                      Text(endTime,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _weeklySchedule[day]!['start'] = startTime;
                        _weeklySchedule[day]!['end'] = endTime;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMaxJobsPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('Max Jobs Per Day',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [3, 4, 5, 6, 7, 8, 10].map((count) {
              final isSelected = _maxJobsPerDay == count;
              return InkWell(
                onTap: () {
                  setState(() => _maxJobsPerDay = count);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(count.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _showBufferTimePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('Buffer Time Between Jobs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [15, 30, 45, 60, 90].map((mins) {
              final isSelected = _bufferTime == mins;
              return InkWell(
                onTap: () {
                  setState(() => _bufferTime = mins);
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      mins < 60 ? '$mins mins' : '${mins ~/ 60}h ${mins % 60}m',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _showAddBlockedDatePicker() {
    final reasonCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                const Text('Block Date',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setModal(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Text(
                        '${selectedDate.day} ${_monthName(selectedDate.month)} ${selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'Reason (optional)',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _blockedDates.add({
                          'date':
                              '${selectedDate.day} ${_monthName(selectedDate.month)} ${selectedDate.year}',
                          'isoDate': selectedDate.toIso8601String(),
                          'reason': reasonCtrl.text.isEmpty
                              ? 'Blocked'
                              : reasonCtrl.text,
                        });
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Block Date',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
