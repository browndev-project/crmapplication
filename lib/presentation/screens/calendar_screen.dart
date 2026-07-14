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
          // Extremely compact single-row header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                // Navigation Group
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactNavButton(Icons.chevron_left, () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                      });
                      _fetchEventsForMonth(_focusedDay);
                    }, isDark, leftRound: true),
                    const SizedBox(width: 1),
                    _buildCompactNavButton(Icons.chevron_right, () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                      });
                      _fetchEventsForMonth(_focusedDay);
                    }, isDark, rightRound: true),
                    const SizedBox(width: 4),
                    _buildCompactNavButton(Icons.today_outlined, () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                      });
                      _fetchEventsForMonth(_focusedDay);
                    }, isDark, allRound: true),
                  ],
                ),
                
                // Centered Month Year (Clickable for fast nav)
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('MMM yyyy').format(_focusedDay),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // View Toggle Group
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactToggle('M', CalendarFormat.month, isDark, leftRound: true),
                    const SizedBox(width: 1),
                    _buildCompactToggle('W', CalendarFormat.week, isDark, rightRound: true),
                  ],
                ),
              ],
            ),
          ),
          


          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
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
                headerVisible: false, // We use custom header above
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.3),
                    shape: BoxShape.rectangle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.rectangle,
                  ),
                  defaultDecoration: const BoxDecoration(shape: BoxShape.rectangle),
                  weekendDecoration: const BoxDecoration(shape: BoxShape.rectangle),
                  outsideDecoration: const BoxDecoration(shape: BoxShape.rectangle),
                  markersMaxCount: 4,
                  cellMargin: const EdgeInsets.all(4.0),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox();
                    
                    return Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: events.take(4).map((event) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                            color: event.eventType == 'task' 
                                ? (isDark ? Colors.white : Colors.black) 
                                : const Color(0xFFF97316),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactNavButton(IconData icon, VoidCallback onTap, bool isDark, {bool leftRound = false, bool rightRound = false, bool allRound = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : const Color(0xFF2C3E50),
          borderRadius: allRound 
              ? BorderRadius.circular(4)
              : BorderRadius.only(
                  topLeft: leftRound ? const Radius.circular(4) : Radius.zero,
                  bottomLeft: leftRound ? const Radius.circular(4) : Radius.zero,
                  topRight: rightRound ? const Radius.circular(4) : Radius.zero,
                  bottomRight: rightRound ? const Radius.circular(4) : Radius.zero,
                ),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCompactToggle(String label, CalendarFormat format, bool isDark, {bool leftRound = false, bool rightRound = false}) {
    final isSelected = _calendarFormat == format;
    return InkWell(
      onTap: () {
        setState(() {
          _calendarFormat = format;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? const Color(0xFF1E2130) : const Color(0xFF2C3E50))
              : (isDark ? const Color(0xFF2C2F3F) : const Color(0xFF7F8C8D)),
          borderRadius: BorderRadius.only(
            topLeft: leftRound ? const Radius.circular(4) : Radius.zero,
            bottomLeft: leftRound ? const Radius.circular(4) : Radius.zero,
            topRight: rightRound ? const Radius.circular(4) : Radius.zero,
            bottomRight: rightRound ? const Radius.circular(4) : Radius.zero,
          ),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final isTask = event.eventType == 'task';
                    // Use black for tasks as requested, but ensure it is visible in dark mode
                    final color = isTask 
                        ? (isDark ? Colors.white : Colors.black) 
                        : const Color(0xFFF97316);
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.1)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.jm().format(event.dateTime),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (event.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    event.description,
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                    softWrap: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      }
    );
  }
}
