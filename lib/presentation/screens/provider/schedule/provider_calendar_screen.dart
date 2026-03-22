// lib/presentation/screens/provider/schedule/provider_calendar_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProviderCalendarScreen extends StatefulWidget {
  const ProviderCalendarScreen({Key? key}) : super(key: key);

  @override
  State<ProviderCalendarScreen> createState() => _ProviderCalendarScreenState();
}

class _ProviderCalendarScreenState extends State<ProviderCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  bool _isLoading = true;

  List<Map<String, dynamic>> _allBookings = [];
  StreamSubscription<QuerySnapshot>? _sub;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _sub = FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: _uid)
        .where('status', whereIn: [
          'confirmed',
          'accepted',
          'in_progress',
          'pending_provider_confirmation',
          'pending'
        ])
        .snapshots()
        .listen((snap) {
          _allBookings =
              snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          if (mounted) setState(() => _isLoading = false);
        }, onError: (_) {
          if (mounted) setState(() => _isLoading = false);
        });
  }

  // Get bookings for a specific date
  List<Map<String, dynamic>> _bookingsForDate(DateTime date) {
    return _allBookings.where((b) {
      final sd = b['scheduledDate'];
      DateTime? dt;
      if (sd is Timestamp) dt = sd.toDate();
      if (sd is String) dt = DateTime.tryParse(sd);
      if (dt == null) return false;
      return dt.year == date.year &&
          dt.month == date.month &&
          dt.day == date.day;
    }).toList()
      ..sort((a, b) {
        final aDate = _parseDate(a['scheduledDate']);
        final bDate = _parseDate(b['scheduledDate']);
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
  }

  // Get job count per day for the focused month
  Map<int, int> get _jobsPerDay {
    final Map<int, int> counts = {};
    for (final b in _allBookings) {
      final sd = b['scheduledDate'];
      DateTime? dt;
      if (sd is Timestamp) dt = sd.toDate();
      if (sd is String) dt = DateTime.tryParse(sd);
      if (dt == null) continue;
      if (dt.year == _focusedMonth.year && dt.month == _focusedMonth.month) {
        counts[dt.day] = (counts[dt.day] ?? 0) + 1;
      }
    }
    return counts;
  }

  DateTime? _parseDate(dynamic sd) {
    if (sd is Timestamp) return sd.toDate();
    if (sd is String) return DateTime.tryParse(sd);
    return null;
  }

  String _formatTime(Map<String, dynamic> booking) {
    final sd = booking['scheduledDate'];
    DateTime? dt;
    if (sd is Timestamp) dt = sd.toDate();
    if (sd is String) dt = DateTime.tryParse(sd);

    // For quote-based bookings the time is in scheduledDate ISO string
    if (dt != null && (dt.hour != 0 || dt.minute != 0)) {
      return DateFormat('HH:mm').format(dt);
    }

    // For direct bookings the time is in scheduledTime field
    final timeStr = booking['scheduledTime']?.toString() ?? '';
    if (timeStr.isNotEmpty) {
      // Handle "09:00 AM" or "09:00" format
      try {
        if (timeStr.contains('AM') || timeStr.contains('PM')) {
          final parsed = DateFormat('hh:mm a').parse(timeStr);
          return DateFormat('HH:mm').format(parsed);
        }
        return timeStr.split(':').take(2).join(':');
      } catch (_) {
        return timeStr;
      }
    }
    return '—';
  }

  String _getAmPm(Map<String, dynamic> booking) {
    final sd = booking['scheduledDate'];
    DateTime? dt;
    if (sd is Timestamp) dt = sd.toDate();
    if (sd is String) dt = DateTime.tryParse(sd);
    if (dt != null && (dt.hour != 0 || dt.minute != 0)) {
      return dt.hour < 12 ? 'AM' : 'PM';
    }
    final timeStr = booking['scheduledTime']?.toString() ?? '';
    if (timeStr.contains('AM')) return 'AM';
    if (timeStr.contains('PM')) return 'PM';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayJobs = _bookingsForDate(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text('Schedule',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => context.push('/provider-availability'),
            icon: const Icon(Icons.settings, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(children: [
              _buildCalendar(),
              _buildSelectedDateHeader(selectedDayJobs.length),
              Expanded(
                child: selectedDayJobs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: selectedDayJobs.length,
                        itemBuilder: (context, i) =>
                            _buildJobCard(selectedDayJobs[i]),
                      ),
              ),
            ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final jobCounts = _jobsPerDay;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
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
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(() {
                _focusedMonth =
                    DateTime(_focusedMonth.year, _focusedMonth.month - 1);
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => setState(() {
                _focusedMonth =
                    DateTime(_focusedMonth.year, _focusedMonth.month + 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _WeekdayHeader('Sun'),
            _WeekdayHeader('Mon'),
            _WeekdayHeader('Tue'),
            _WeekdayHeader('Wed'),
            _WeekdayHeader('Thu'),
            _WeekdayHeader('Fri'),
            _WeekdayHeader('Sat'),
          ],
        ),
        const SizedBox(height: 8),

        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final dayNumber = index - startingWeekday + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox();
            }

            final date =
                DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
            final isSelected = _isSameDay(date, _selectedDate);
            final isToday = _isSameDay(date, DateTime.now());
            final jobCount = jobCounts[dayNumber] ?? 0;

            return InkWell(
              onTap: () => setState(() => _selectedDate = date),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black
                      : isToday
                          ? Colors.grey[100]
                          : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayNumber.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                    if (jobCount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildSelectedDateHeader(int jobCount) {
    final dayName = _dayName(_selectedDate.weekday);
    final month = _monthName(_selectedDate.month);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$dayName, ${_selectedDate.day} $month',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              jobCount == 0
                  ? 'No jobs scheduled'
                  : '$jobCount job${jobCount == 1 ? '' : 's'} scheduled',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ]),
          TextButton(
            onPressed: () => setState(() {
              _selectedDate = DateTime.now();
              _focusedMonth = DateTime.now();
            }),
            child: const Text('Today',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString() ?? '';
    final clientName = booking['clientName']?.toString() ?? 'Client';
    final category = booking['serviceCategory']?.toString() ??
        booking['category']?.toString() ??
        'Service';
    final status = booking['status']?.toString() ?? 'confirmed';
    final address = booking['address']?.toString() ?? '—';
    final source = booking['source']?.toString() ?? '';
    final scheduledDate = _parseDate(booking['scheduledDate']);
    final timeStr = _formatTime(booking);
    final amPm = _getAmPm(booking);

    final isConfirmed = status == 'confirmed' || status == 'accepted';
    final isInProgress = status == 'in_progress';
    final statusColor = isInProgress
        ? Colors.purple
        : isConfirmed
            ? Colors.green
            : Colors.orange;
    final statusLabel = isInProgress
        ? 'In Progress'
        : isConfirmed
            ? 'Confirmed'
            : 'Pending';

    return GestureDetector(
      onTap: () => context.push('/provider-job-detail', extra: bookingId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A000000)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Row(children: [
          // Time block
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              Text(timeStr,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor)),
              Text(amPm, style: TextStyle(fontSize: 11, color: statusColor)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(clientName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
            if (source == 'quote') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Text('From Quote',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No jobs scheduled',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Jobs for this day will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ]),
    );
  }

  void _showAddOptions() {
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
          const Text('Add to Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ListTile(
            onTap: () {
              Navigator.pop(ctx);
              context.push('/provider-availability');
            },
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.block, color: Colors.red[700]),
            ),
            title: const Text('Block Time',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Mark time as unavailable',
                style: TextStyle(color: Colors.grey[600])),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _dayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String day;
  const _WeekdayHeader(this.day);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(day,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600])),
    );
  }
}
