import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/report_service.dart';
import '../../data/models/call_log_model.dart';
import '../../data/models/todays_report_model.dart';

class CallLogsBottomSheet extends ConsumerStatefulWidget {
  final EmployeeReportV2 employee;
  final bool isDark;
  final String? fromDate;
  final String? toDate;

  const CallLogsBottomSheet({
    super.key,
    required this.employee,
    required this.isDark,
    this.fromDate,
    this.toDate,
  });

  @override
  ConsumerState<CallLogsBottomSheet> createState() => _CallLogsBottomSheetState();
}

class _CallLogsBottomSheetState extends ConsumerState<CallLogsBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<GroupedCallItem> _groups = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
        _fetchGroups();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroups() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(reportServiceProvider);
      final response = await service.fetchEmployeeGroupedCalls(
        widget.employee.employeeId,
        from: widget.fromDate,
        to: widget.toDate,
        page: _page,
        limit: 10,
      );

      setState(() {
        _groups.addAll(response.data);
        _page++;
        _hasMore = _page <= response.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openDetailedCalls(String phone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DetailedCallsBottomSheet(
        phone: phone,
        employeeId: widget.employee.employeeId,
        employeeName: widget.employee.name,
        isDark: widget.isDark,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      ),
    );
  }

  String _formatDurationShort(int seconds) {
    if (seconds == 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0 || h > 0) parts.add('${m}m');
    parts.add('${s}s');
    return parts.join(' ');
  }

  Widget _buildGroupedCallCard(GroupedCallItem group, bool isDark) {
    final latestCall = group.latestCall;
    final isIncoming = latestCall?.callType.toUpperCase() == 'INCOMING';
    final latestCallTime = group.latestCallTime ?? latestCall?.startTime ?? latestCall?.createdAt;
    
    // Status color & label
    final statusInfo = latestCall != null ? getCallConnectionStatus(latestCall) : const CallStatusInfo('Unknown', Colors.grey);
    final isConnected = statusInfo.label == 'Connected';
    final statusColor = statusInfo.color;
    final statusBgColor = statusColor.withValues(alpha: 0.1);
    
    final initiatedBy = latestCall?.initiatorName.isNotEmpty == true 
        ? latestCall!.initiatorName 
        : widget.employee.name;
        
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _openDetailedCalls(group.phone),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Phone Number & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isIncoming ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isIncoming ? Icons.call_received : Icons.call_made,
                          color: isIncoming ? Colors.green : Colors.blue,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Text(
                            group.phone,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${group.totalCalls})',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? statusColor.withValues(alpha: 0.15) : statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusInfo.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Initiated By
              Padding(
                padding: const EdgeInsets.only(left: 48.0),
                child: Text(
                  'Initiated By: $initiatedBy',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Bottom Row: Duration/Type Badge & Date Time
              Padding(
                padding: const EdgeInsets.only(left: 48.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                                                 if (isConnected && getActiveDuration(latestCall) > 0)
                          Text(
                            'Latest: ${_formatDurationShort(getActiveDuration(latestCall))}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          )
                        else
                          Text(
                            statusInfo.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        const SizedBox(width: 8),
                        
                        // Call Type Badge
                        if (latestCall != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isIncoming ? Colors.green.shade300 : Colors.blue.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              latestCall.callType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isIncoming ? Colors.green.shade700 : Colors.blue.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    if (latestCallTime != null)
                      Text(
                        DateFormat('dd/MM/yyyy, HH:mm').format(latestCallTime.toLocal()),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Call Logs - ${widget.employee.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoading && _groups.isEmpty)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _groups.isEmpty && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_missed, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No call logs found for this agent.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _groups.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _groups.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _buildGroupedCallCard(_groups[index], widget.isDark);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DetailedCallsBottomSheet extends ConsumerStatefulWidget {
  final String phone;
  final String employeeId;
  final String employeeName;
  final bool isDark;
  final String? fromDate;
  final String? toDate;

  const DetailedCallsBottomSheet({
    super.key,
    required this.phone,
    required this.employeeId,
    required this.employeeName,
    required this.isDark,
    this.fromDate,
    this.toDate,
  });

  @override
  ConsumerState<DetailedCallsBottomSheet> createState() => _DetailedCallsBottomSheetState();
}

class _DetailedCallsBottomSheetState extends ConsumerState<DetailedCallsBottomSheet> {
  List<DetailedCall> _calls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final service = ref.read(reportServiceProvider);
      final details = await service.fetchCallGroupDetails(
        widget.employeeId,
        widget.phone,
        from: widget.fromDate,
        to: widget.toDate,
      );
      setState(() {
        _calls = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatDurationShort(int seconds) {
    if (seconds == 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0 || h > 0) parts.add('${m}m');
    parts.add('${s}s');
    return parts.join(' ');
  }

  Widget _buildDetailedCallCard(DetailedCall call, bool isDark) {
    final isIncoming = call.callType.toUpperCase() == 'INCOMING';
    final callDate = call.startTime ?? call.createdAt;
    
    final statusInfo = getCallConnectionStatus(call);
    final isConnected = statusInfo.label == 'Connected';
    final statusColor = statusInfo.color;
    final statusBgColor = statusColor.withValues(alpha: 0.1);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isIncoming ? Icons.call_received : Icons.call_made,
                      color: isIncoming ? Colors.green : Colors.blue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isIncoming ? Colors.green.shade300 : Colors.blue.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        call.callType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isIncoming ? Colors.green.shade700 : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? statusColor.withValues(alpha: 0.15) : statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusInfo.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isConnected && getActiveDuration(call) > 0)
                      Text(
                        'Duration: ${_formatDurationShort(getActiveDuration(call))}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      )
                    else
                      Text(
                        statusInfo.label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: statusColor),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Source: ${call.source.toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                if (callDate != null)
                  Text(
                    DateFormat('dd/MM/yyyy, HH:mm').format(callDate.toLocal()),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Call Logs - ${widget.phone}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _calls.isEmpty
                        ? Center(
                            child: Text(
                              'No detailed logs found.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _calls.length,
                            itemBuilder: (context, index) {
                              return _buildDetailedCallCard(_calls[index], widget.isDark);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
