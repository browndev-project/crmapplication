import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/report_service.dart';
import '../../../data/models/service_report_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/dashboard_stats_card.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../widgets/access_denied_widget.dart';

// Provider using family for caching/refetching based on dates
final servicesReportProvider = FutureProvider.family<ServiceReportModel, String>((ref, key) async {
  final parts = key.split('|');
  final from = DateTime.parse(parts[0]);
  final to = DateTime.parse(parts[1]);

  final service = ref.read(reportServiceProvider);
  return service.fetchServicesReport(from, to);
});

class ServicesReportScreen extends ConsumerStatefulWidget {
  const ServicesReportScreen({super.key});

  @override
  ConsumerState<ServicesReportScreen> createState() => _ServicesReportScreenState();
}

class _ServicesReportScreenState extends ConsumerState<ServicesReportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  
  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_fromDate.isAfter(_toDate)) _toDate = _fromDate;
        } else {
          _toDate = picked;
          if (_toDate.isBefore(_fromDate)) _fromDate = _toDate;
        }
      });
    }
  }

  Future<void> _exportAsCSV(List<ServiceReportItem> services) async {
    try {
      final List<List<dynamic>> rows = [
        ['Service Name', 'Leads Received', 'Leads Closed', 'Conversion Rate %', 'Conversion Share %', 'Amount Share %', 'Max Deal Amount']
      ];
      
      for (final service in services) {
        rows.add([
          service.serviceName,
          service.leadsReceived,
          service.leadsClosed,
          service.conversionRate,
          service.conversionShare,
          service.amountShare,
          service.maxDeal?.amount ?? 0,
        ]);
      }
      
      final csvString = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Services_Report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Services Report CSV');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.hasModule(
      PermissionModules.REPORTS_SERVICES,
      userRole: userRole,
    );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: "Services"),
        body: AccessDeniedWidget(
          sectionName: "Services Report",
          showAppBar: false,
        ),
      );
    }

    final requestKey = '${_fromDate.toIso8601String()}|${_toDate.toIso8601String()}';
    final reportAsync = ref.watch(servicesReportProvider(requestKey));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlobalAppBar(
        title: 'Services Report',
        actions: [
          reportAsync.maybeWhen(
            data: (report) => IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
              onPressed: () => _exportAsCSV(report.services),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),

      body: Column(
        children: [
          Container(height: 5, color: const Color(0xFFFFE100)), // Blinkit yellow strip
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(servicesReportProvider(requestKey)),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Date Info
                    const Text("Services Report", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      "Showing data from ${_dateFormat.format(_fromDate)} to ${_dateFormat.format(_toDate)}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)
                    ),
                    const SizedBox(height: 20),
                    
                    // Controls Row (Date Pickers & Refresh)
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker(context, "From", _fromDate, () => _selectDate(context, true))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDatePicker(context, "To", _toDate, () => _selectDate(context, false))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats Summary (Blinkit Style)
                    reportAsync.when(
                      data: (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                 Expanded(child: DashboardStatsCard(title: "Received", value: report.totals.leadsReceived.toString(), icon: Icons.inbox, backgroundColor: Colors.orange, gradientColors: const [Colors.orange, Colors.deepOrange])),
                                 const SizedBox(width: 8),
                                 Expanded(child: DashboardStatsCard(title: "Closed", value: report.totals.leadsClosed.toString(), icon: Icons.check_circle, backgroundColor: Colors.green, gradientColors: const [Colors.green, Colors.teal])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                 Expanded(child: DashboardStatsCard(title: "Revenue", value: "₹${NumberFormat('#,##,###').format(report.totals.totalRevenue)}", icon: Icons.account_balance_wallet, backgroundColor: Colors.blue, gradientColors: const [Colors.blue, Colors.indigo])),
                                 const SizedBox(width: 8),
                                 const Expanded(child: SizedBox()),
                              ],
                            )
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                    // Report Cards List
                    reportAsync.when(
                      data: (report) {
                        if (report.services.isEmpty) {
                          return _buildEmptyState();
                        }

                        return Column(
                          children: report.services.map((service) => 
                            _ServiceCard(
                              service: service, 
                              totalRevenue: report.totals.totalRevenue, 
                            )
                          ).toList(),
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator(color: Colors.black))),
                      error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Failed to load report: $err', style: const TextStyle(color: Colors.red)))),
                    ),
                    
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        "Last updated at ${DateFormat('hh:mm a').format(DateTime.now())}", 
                        style: TextStyle(color: Colors.grey[400], fontSize: 11, fontStyle: FontStyle.italic)
                      )
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            const Text("No data found for this period", style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, String label, DateTime date, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                   Text(_dateFormat.format(date), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final ServiceReportItem service;
  final int totalRevenue;
  
  const _ServiceCard({
    required this.service,
    required this.totalRevenue,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final convColor = service.conversionRate > 20 
        ? Colors.green 
        : (service.conversionRate > 0 ? Colors.orange : Colors.grey);
    
    // Calculate amount from share
    final double computedAmount = (service.amountShare / 100.0) * widget.totalRevenue;
    
    String topConvName = "-";
    if (service.topPerformerByConversion != null) {
      if (service.topPerformerByConversion is Map) {
        topConvName = service.topPerformerByConversion['name'] ?? service.topPerformerByConversion['userName'] ?? "-";
      } else {
        topConvName = service.topPerformerByConversion.toString();
      }
    }
    
    String topAmtName = "-";
    if (service.topPerformerByAmount != null) {
      if (service.topPerformerByAmount is Map) {
        topAmtName = service.topPerformerByAmount['name'] ?? service.topPerformerByAmount['userName'] ?? "-";
      } else {
        topAmtName = service.topPerformerByAmount.toString();
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service.serviceName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Grid of primary metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem("Received", "${service.leadsReceived}", Colors.orange),
                      _buildMetricItem("Closed", "${service.leadsClosed}", Colors.green),
                      _buildMetricItem(
                        "Conv. %", 
                        "${service.conversionRate.toStringAsFixed(1)}%", 
                        convColor,
                      ),
                      _buildMetricItem(
                        "Amount", 
                        "₹${NumberFormat('#,##,###').format(computedAmount.round())}", 
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DETAILED INSIGHTS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInsightRow("Top Performer (Conv)", topConvName, Icons.trending_up, Colors.purple),
                  _buildInsightRow("Top Performer (Amt)", topAmtName, Icons.monetization_on, Colors.blue),
                  _buildInsightRow("Max Deal Reached", "₹${NumberFormat('#,##,###').format(service.maxDeal?.amount ?? 0)}", Icons.stars, Colors.amber),
                  const SizedBox(height: 20),
                  // Charts stacked vertically
                  _buildChartContainer("Lead Progression", _buildBarChart(service)),
                  const SizedBox(height: 16),
                  _buildChartContainer("Ratio", _buildGaugeChart(service)),
                  const SizedBox(height: 16),
                  _buildChartContainer("Share", _buildPieChart(service)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildInsightRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.02),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildBarChart(ServiceReportItem item) {
    final received = item.leadsReceived.toDouble();
    final closed = item.leadsClosed.toDouble();
    final maxY = received > 0 ? received + (received * 0.2) : 10.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.round().toString(),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                if (val == 0) return const Text('Received', style: TextStyle(fontSize: 10));
                if (val == 1) return const Text('Closed', style: TextStyle(fontSize: 10));
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: received, color: Colors.black, width: 14, borderRadius: BorderRadius.circular(2))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: closed, color: Colors.green, width: 14, borderRadius: BorderRadius.circular(2))]),
        ],
      ),
    );
  }

  Widget _buildGaugeChart(ServiceReportItem item) {
    final rate = item.conversionRate.toDouble();
    return PieChart(
      PieChartData(
        startDegreeOffset: 270,
        sectionsSpace: 0,
        centerSpaceRadius: 25,
        sections: [
          PieChartSectionData(
            color: Colors.green,
            value: rate,
            title: '',
            radius: 8,
          ),
          PieChartSectionData(
            color: Colors.grey.shade200,
            value: (100 - rate).abs(),
            title: '',
            radius: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(ServiceReportItem item) {
    final share = item.conversionShare.toDouble();
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 0,
        sections: [
          PieChartSectionData(value: share, color: Colors.blue, radius: 25, title: ''),
          PieChartSectionData(value: (100 - share).abs(), color: Colors.grey.shade200, radius: 25, title: ''),
        ],
      ),
    );
  }
}
