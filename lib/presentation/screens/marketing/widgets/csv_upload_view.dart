import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/permission_constants.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/login_provider.dart';
import '../../../../data/models/lead_model.dart';
import 'send_email_dialog.dart';

class CsvUploadView extends ConsumerStatefulWidget {
  const CsvUploadView({super.key});

  @override
  ConsumerState<CsvUploadView> createState() => _CsvUploadViewState();
}

class _CsvUploadViewState extends ConsumerState<CsvUploadView> {
  List<String> _emails = [];
  bool _isLoading = false;
  String? _fileName;

  Future<void> _pickAndParseCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
      );

      if (result == null) return;

      setState(() {
        _isLoading = true;
        _fileName = result.files.first.name;
      });

      final file = result.files.first;
      List<String> extractedEmails = [];

      // Parse CSV
      if (file.path != null) {
        final input = File(file.path!).readAsStringSync();
        final rows = const CsvToListConverter().convert(input);

        if (rows.isEmpty) {
          throw 'CSV file is empty';
        }

        // Find email column index (case-insensitive)
        final headers = rows[0].map((e) => e.toString().toLowerCase()).toList();
        final emailIndex = headers.indexWhere((h) => h.contains('email'));

        if (emailIndex == -1) {
          throw 'No "Email" column found in CSV';
        }

        // Extract emails from rows (skip header)
        for (int i = 1; i < rows.length; i++) {
          if (emailIndex < rows[i].length) {
            final email = rows[i][emailIndex].toString().trim();
            if (email.isNotEmpty && email.contains('@')) {
              extractedEmails.add(email);
            }
          }
        }
      } else if (file.bytes != null) {
        // Web support
        final input = utf8.decode(file.bytes!);
        final rows = const CsvToListConverter().convert(input);

        if (rows.isEmpty) {
          throw 'CSV file is empty';
        }

        final headers = rows[0].map((e) => e.toString().toLowerCase()).toList();
        final emailIndex = headers.indexWhere((h) => h.contains('email'));

        if (emailIndex == -1) {
          throw 'No "Email" column found in CSV';
        }

        for (int i = 1; i < rows.length; i++) {
          if (emailIndex < rows[i].length) {
            final email = rows[i][emailIndex].toString().trim();
            if (email.isNotEmpty && email.contains('@')) {
              extractedEmails.add(email);
            }
          }
        }
      }

      if (extractedEmails.isEmpty) {
        throw 'No valid emails found in CSV';
      }

      setState(() {
        _emails = extractedEmails;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${extractedEmails.length} emails extracted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeEmail(int index) {
    setState(() {
      _emails.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _emails.clear();
      _fileName = null;
    });
  }

  // Convert emails to Lead objects for the existing dialog
  List<Lead> _convertEmailsToLeads() {
    return _emails.map<Lead>((email) {
      return Lead(
        id: '',
        leadId: 'NEW',
        name: email.split('@').first, // Use email prefix as name
        email: email,
        phoneNo: '',
        description: '',
        status: 'new',
        source: 'CSV Import',
        pipeline: 'default',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Marketing Recipients",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (_emails.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('CLEAR ALL'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_emails.isEmpty)
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.blueGrey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.upload_file_rounded,
                        size: 48,
                        color: isDark
                            ? Colors.grey[400]
                            : Colors.blueGrey.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isLoading ? "Processing..." : "Drag & Drop your CSV file here",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Supports .csv, .xls, .xlsx",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickAndParseCSV,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: Text(_isLoading ? "PROCESSING..." : "BROWSE FILES"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.blue : Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Text(
                            "Mandatory column: Email",
                            style: TextStyle(
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.blue.shade100,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.email_outlined,
                                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_emails.length} Recipients',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  if (_fileName != null)
                                    Text(
                                      'From: $_fileName',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                             if (ref.watch(permissionsProvider).hasPermission(PermissionModules.MARKETING_MAIL, userRole: ref.watch(loginProvider).user?.systemRole) &&
                                 ref.watch(permissionsProvider).hasModule(PermissionModules.TOOLS, userRole: ref.watch(loginProvider).user?.systemRole))
                                ElevatedButton(
                                  onPressed: () {
                                    // Convert emails to Lead objects and open the existing dialog
                                    showDialog(
                                      context: context,
                                      builder: (_) => SendEmailDialog(
                                        recipients: _convertEmailsToLeads(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.blue : Colors.black,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  child: const Text(
                                    'SEND EMAIL',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email List
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _emails.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        ),
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isDark
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.blue.shade100,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ),
                            title: Text(
                              _emails[index],
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.close,
                                  size: 18,
                                  color: isDark ? Colors.red.shade300 : Colors.red),
                              onPressed: () => _removeEmail(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
