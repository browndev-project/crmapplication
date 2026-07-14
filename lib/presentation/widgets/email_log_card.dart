import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/email_log_model.dart';

class EmailLogCard extends StatelessWidget {
  final EmailLogModel log;

  const EmailLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
 isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Recipients, Provider, Mail Type
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recipients', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Text(
                      '${log.recipients.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Provider', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        _buildProviderChip(log.provider),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Mail Type', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        _buildTypeChip(log.type),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Subject
          Text('Subject', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(log.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          
          // Mailed By
          Text('Mailed By', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('${log.mailedByName} - Company', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          
          // Email Used
          Text('Email Used', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(log.senderMail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          
          // Employee Email
          Text('Employee Email', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(log.employeeEmail.isNotEmpty ? log.employeeEmail : 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          
          // Bottom Row: MailsSent, Created
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MailsSent', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Text('${log.mailsSent}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Created', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Text(timeago.format(log.createdAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String provider) {
    Color color = Colors.blue; // Default for Gmail
    if (provider.toLowerCase() == 'outlook') color = Colors.lightBlue;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        provider.toUpperCase().replaceAll('CUSTOM', 'GMAIL'), // Generic custom often means gmail in this app
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    Color bgColor;
    Color textColor = Colors.white;
    
    switch (type.toLowerCase()) {
      case 'personal':
        bgColor = Colors.blue;
        break;
      case 'meeting':
        bgColor = Colors.yellowAccent.shade700;
        textColor = Colors.black;
        break;
      case 'marketing':
        bgColor = Colors.green;
        break;
      default:
        bgColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : 'Unknown',
        style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
