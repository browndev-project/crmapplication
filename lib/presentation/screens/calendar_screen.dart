import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../data/models/calendar_event_model.dart';
import '../providers/calendar_provider.dart';
import '../widgets/global_app_bar.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../widgets/access_denied_widget.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final permissions = ref.read(permissionsProvider);
      final userRole = ref.read(loginProvider).user?.systemRole;
      final hasAccess = (permissions.hasModule(PermissionModules.CALENDAR, userRole: userRole) &&
              permissions.hasPermission(PermissionModules.CALENDAR_VIEW, userRole: userRole)) ||
          (permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
              permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole));
      if (hasAccess) {
        _fetchEventsForMonth(_focusedDay);
      }
    });
  }

  void _fetchEventsForMonth(DateTime date) {
    // Fetch a bit before and after the month to cover the entire grid
    final start = DateTime(date.year, date.month - 1, 15);
    final end = DateTime(date.year, date.month + 1, 15);
    ref.read(calendarProvider.notifier).fetchEvents(start, end);
  }

  List<CalendarEvent> _getEventsForDay(DateTime day, List<CalendarEvent> allEvents) {
    return allEvents.where((event) => isSameDay(event.dateTime, day)).toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _focusedDay) {
      setState(() {
        _focusedDay = picked;
        _selectedDay = picked;
      });
      _fetchEventsForMonth(_focusedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final hasAccess = (permissions.hasModule(PermissionModules.CALENDAR, userRole: userRole) &&
            permissions.hasPermission(PermissionModules.CALENDAR_VIEW, userRole: userRole)) ||
        (permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
            permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole));

    if (!hasAccess) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Events Calendar'),
        body: AccessDeniedWidget(
          sectionName: "Calendar",
          showAppBar: false,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calendarState = ref.watch(calendarProvider);

    return Scaffold(

      appBar: const GlobalAppBar(title: 'Events Calendar'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header matching screenshot concept
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                // Navigation Capsule Group
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                          });
                          _fetchEventsForMonth(_focusedDay);
                        },
                        child: Icon(Icons.chevron_left_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _focusedDay = DateTime.now();
                            _selectedDay = DateTime.now();
                          });
                          _fetchEventsForMonth(_focusedDay);
                        },
                        child: Icon(Icons.calendar_month_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                          });
                          _fetchEventsForMonth(_focusedDay);
                        },
                        child: Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
                
                // Centered Month Year (Clickable for fast nav)
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('MMM yyyy').format(_focusedDay),
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // View Toggle Pill Group
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _calendarFormat = CalendarFormat.month;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _calendarFormat == CalendarFormat.month
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'M',
                            style: TextStyle(
                              color: _calendarFormat == CalendarFormat.month
                                  ? Colors.white
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _calendarFormat = CalendarFormat.week;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _calendarFormat == CalendarFormat.week
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'W',
                            style: TextStyle(
                              color: _calendarFormat == CalendarFormat.week
                                  ? Colors.white
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TableCalendar<CalendarEvent>(
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
                CalendarFormat.week: 'Week',
              },
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                
                final events = _getEventsForDay(selectedDay, calendarState.events);
                if (events.isNotEmpty) {
                  _showEventsDialog(context, selectedDay, events);
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _fetchEventsForMonth(focusedDay);
              },
              eventLoader: (day) => _getEventsForDay(day, calendarState.events),
              headerVisible: false,
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13),
                weekendStyle: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFC2410C), fontSize: 13),
              ),
              calendarStyle: const CalendarStyle(
                defaultDecoration: BoxDecoration(shape: BoxShape.circle),
                weekendDecoration: BoxDecoration(shape: BoxShape.circle),
                outsideDecoration: BoxDecoration(shape: BoxShape.circle),
                cellMargin: EdgeInsets.all(3.0),
              ),
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, date, _) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
                todayBuilder: (context, date, _) {
                  final isSelected = isSameDay(_selectedDay, date);
                  if (isSelected) return null;
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 1),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                outsideBuilder: (context, date, _) {
                  return Container(
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(color: isDark ? Colors.white30 : Colors.grey[350]),
                    ),
                  );
                },
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox();
                  
                  final hasMeeting = events.any((e) => e.eventType == 'meeting' || e.eventType == 'visit');
                  final hasFollowUp = events.any((e) => e.eventType == 'task');
                  
                  Color dotColor = const Color(0xFF2563EB);
                  if (hasFollowUp && !hasMeeting) {
                    dotColor = const Color(0xFFC2410C);
                  }
                  
                  final isSelected = isSameDay(_selectedDay, date);
                  final isTodayDay = isSameDay(DateTime.now(), date);
                  if (isSelected || isTodayDay) return const SizedBox();

                  return Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Legend Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Meeting',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC2410C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Follow up',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEventsDialog(BuildContext context, DateTime date, List<CalendarEvent> events) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(date),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final isTask = event.eventType == 'task';
                    final color = isTask 
                        ? const Color(0xFFC2410C)
                        : const Color(0xFF2563EB);
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 5,
                                color: color,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              event.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 20,
                                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          DateFormat.jm().format(event.dateTime),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      if (event.description.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          event.description,
                                          style: TextStyle(
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                          softWrap: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      }
    );
  }
}
