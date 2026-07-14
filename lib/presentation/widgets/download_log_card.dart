import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/download_log_model.dart';

class DownloadLogCard extends StatelessWidget {
  final DownloadLogModel log;

  const DownloadLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;

    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.normal,
      color: isDark ? Colors.white54 : Colors.grey.shade500,
    );

    final valueStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14,
      color: isDark ? Colors.white : Colors.black87,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Module, Format, Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Module',
                      style: labelStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.module,
                      style: valueStyle,
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Format',
                      style: labelStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.format.toUpperCase(),
                      style: valueStyle,
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Status',
                      style: labelStyle,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: log.status.toLowerCase() == 'success'
                            ? const Color(0xFF00897B)
                            : (log.status.toLowerCase() == 'failed'
                                ? const Color(0xFFD32F2F)
                                : Colors.orange.shade700),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        log.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 2: User
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User',
                  style: labelStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  log.userName,
                  style: valueStyle,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 3: Rows & Created
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rows',
                        style: labelStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${log.rows}',
                        style: valueStyle,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created',
                        style: labelStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(log.createdAt),
                        style: valueStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
