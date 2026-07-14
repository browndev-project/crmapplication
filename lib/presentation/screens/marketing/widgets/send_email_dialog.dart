import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/r2_service.dart';
import '../../../../data/models/lead_model.dart';
import '../../../providers/lead_provider.dart';
import '../../../providers/login_provider.dart';
import '../../../providers/marketing_template_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';


class SendEmailDialog extends ConsumerStatefulWidget {
  final List<Lead> recipients;
  final String? initialSubject;
  final String? initialBody;

  const SendEmailDialog({
    super.key, 
    required this.recipients,
    this.initialSubject,
    this.initialBody,
  });

  @override
  ConsumerState<SendEmailDialog> createState() => _SendEmailDialogState();
}

class _SendEmailDialogState extends ConsumerState<SendEmailDialog> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _recipientController = TextEditingController();
  
  final List<String> _senderProfiles = [];
  String? _selectedSender; // This will hold 'Gmail' or 'Outlook'
  String? _googleEmail;
  String? _outlookEmail;
  bool _isLoadingAuth = true;
  
  // Recipients Logic
  List<Lead> _leadRecipients = [];
  final List<String> _manualRecipients = []; // For manually typed emails
  final _manualRecipientController = TextEditingController();
  final _employeeEmailController = TextEditingController(); // For Employee Email field

  // Templates Logic
  String? _selectedTemplateId;
  bool _saveAsTemplate = false;
  final _templateNameController = TextEditingController();

  // HTML Editor Logic
  InAppWebViewController? _webViewController;

  String _escapeJsString(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll('\'', '\\\'')
        .replaceAll('"', '\\"')
        .replaceAll('\r', '')
        .replaceAll('\n', '\\n');
  }

  String getHtmlTemplate(String initialHtml) {
    return """
  <!DOCTYPE html>
  <html>
  <head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      font-size: 14px;
      line-height: 1.5;
      margin: 0;
      padding: 12px;
      color: #333333;
      background-color: transparent;
      -webkit-tap-highlight-color: transparent;
    }
    [contenteditable] {
      outline: none;
      min-height: 250px;
      height: 100%;
      box-sizing: border-box;
    }
    [contenteditable]:empty:before {
      content: "Compose email...";
      color: #a0aec0;
      cursor: text;
    }
    img {
      max-width: 100%;
      height: auto;
      border-radius: 4px;
    }
  </style>
  <script>
    function format(command, value) {
      document.execCommand(command, false, value);
      sendContent();
    }
    function setHtml(html) {
      document.getElementById('editor').innerHTML = html;
      sendContent();
    }
    function getHtml() {
      return document.getElementById('editor').innerHTML;
    }
    function sendContent() {
      var content = getHtml();
      window.flutter_inappwebview.callHandler('onContentChanged', content);
    }
    window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
      sendContent();
    });
  </script>
  </head>
  <body>
    <div id="editor" contenteditable="true" oninput="sendContent()">$initialHtml</div>
  </body>
  </html>
    """;
  }

  void _undo() {
    _webViewController?.evaluateJavascript(source: "document.execCommand('undo');");
  }

  void _redo() {
    _webViewController?.evaluateJavascript(source: "document.execCommand('redo');");
  }

  void _applyFormat(String command, [String? value]) {
    _webViewController?.evaluateJavascript(
      source: "format('$command', '${value ?? ''}');"
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final colors = {
          'Red': '#e74c3c',
          'Blue': '#3498db',
          'Green': '#2ecc71',
          'Orange': '#e67e22',
          'Purple': '#9b59b6',
          'Yellow': '#f1c40f',
          'Dark Grey': '#34495e',
          'Black': '#000000',
        };
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Text Color", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.entries.map((entry) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _applyFormat('foreColor', entry.value);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Color(int.parse(entry.value.replaceAll('#', '0xff'))),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showLinkPicker() {
    final linkController = TextEditingController(text: 'https://');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Insert Link", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: linkController,
            decoration: const InputDecoration(
              labelText: "URL",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final url = linkController.text.trim();
                _applyFormat('createLink', url);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text("Insert"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadAndInsertImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading selected image...'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final bytes = await file.readAsBytes();
      final r2Service = R2Service();
      
      final r2Key = await r2Service.uploadFile(
        bytes,
        'email-attachments/${DateTime.now().millisecondsSinceEpoch}_$fileName',
        'image/jpeg',
      );

      if (r2Key != null) {
        final imageUrl = '${R2Service.publicBaseUrl}/$r2Key';
        _applyFormat('insertImage', imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded and embedded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw 'Cloudflare R2 signature error';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Get user email from loginProvider (same as meeting form)
    final userEmail = ref.read(loginProvider).user?.email ?? '';
    _employeeEmailController.text = userEmail;
    
    _deduplicateRecipients();
    _checkAuthStatus();
    
    // Fetch Templates
    WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(templateProvider.notifier).fetchTemplates();
    });

    _bodyController.text = widget.initialBody ?? "<p>Hi there,</p><p>This is an important announcement.</p><p>Regards,<br>Trevion CRM</p>";
    if (widget.initialSubject != null) {
      _subjectController.text = widget.initialSubject!;
    }
  }

  void _deduplicateRecipients() {
    final seenEmails = <String>{};
    _leadRecipients = widget.recipients.where((lead) {
      if (lead.email.isEmpty) return false;
      if (seenEmails.contains(lead.email.toLowerCase())) {
        return false;
      }
      seenEmails.add(lead.email.toLowerCase());
      return true;
    }).toList();
  }

  void _addManualRecipient() {
    final email = _manualRecipientController.text.trim();
    if (email.isEmpty) return;
    
    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid email format")));
        return;
    }

    if (!_manualRecipients.contains(email) && !_leadRecipients.any((l) => l.email == email)) {
        setState(() {
            _manualRecipients.add(email);
            _manualRecipientController.clear();
        });
    } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email already added")));
    }
  }

  void _removeRecipient({Lead? lead, String? email}) {
      setState(() {
          if (lead != null) _leadRecipients.remove(lead);
          if (email != null) _manualRecipients.remove(email);
      });
  }

  Future<void> _checkAuthStatus() async {
    final leadService = ref.read(leadServiceProvider);
    
    _senderProfiles.clear();
    setState(() => _isLoadingAuth = true);

    try {
      _googleEmail = await leadService.getGoogleAuthStatus();
    } catch (e) {
      debugPrint('Google Auth Check Failed: $e');
    }

    try {
      _outlookEmail = await leadService.getMicrosoftAuthStatus();
    } catch (e) {
       debugPrint('Microsoft Auth Check Failed: $e');
    }

    String? customEmail;
    try {
      customEmail = await leadService.getCustomEmailStatus();
    } catch (e) {
      debugPrint('Custom Email Check Failed: $e');
    }

    if (mounted) {
      setState(() {
        if (_googleEmail != null) _senderProfiles.add('Gmail');
        if (_outlookEmail != null) _senderProfiles.add('Outlook');
        if (customEmail != null) _senderProfiles.add('Custom Email');
        
        // Auto-select first available option (same as meeting form)
        if (_senderProfiles.isNotEmpty) {
          _selectedSender = _senderProfiles.first;
          // DO NOT update employee email here - keep user's email from loginProvider
        }
        _isLoadingAuth = false;
      });
    }
  }


  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _recipientController.dispose();
    _manualRecipientController.dispose();
    _employeeEmailController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  Widget _buildChip(String label, {required VoidCallback onRemove}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))]
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(label.isNotEmpty ? label : 'No Email', style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            InkWell(
                onTap: onRemove,
                child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
            )
            ],
        ),
      );
  }

  Future<void> _sendEmail() async {
     final recipientEmails = [
        ..._leadRecipients.map((l) => l.email),
        ..._manualRecipients
     ].where((e) => e.isNotEmpty).toList();

     if (recipientEmails.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one recipient")));
         return;
     }
     
     if (_selectedSender == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a sender profile")));
         return;
     }

     final subject = _subjectController.text.trim();
     if (subject.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a subject")));
        return;
     }

     setState(() => _isLoadingAuth = true); // Reuse loading state or add new one

     try {
         final service = ref.read(leadServiceProvider);
         final employeeMail = _employeeEmailController.text.trim();
         
         if (_saveAsTemplate && _templateNameController.text.trim().isNotEmpty) {
             final templateName = _templateNameController.text.trim();
             await ref.read(templateProvider.notifier).createTemplate(
                 name: templateName,
                 subject: subject,
                 body: _bodyController.text
             );
         }
         
         bool success = false;
         if (_selectedSender == 'Gmail') {
             success = await service.sendGoogleBulkEmail(
                subject: subject,
                body: _bodyController.text,
                recipients: recipientEmails,
                employeeMail: employeeMail,
                mailType: 'personal' // Defaulting to personal or marketing? Let's use personal for ad-hoc strings
             );
         } else if (_selectedSender == 'Outlook') {
             success = await service.sendOutlookBulkEmail(
                subject: subject,
                body: _bodyController.text,
                recipients: recipientEmails,
                employeeMail: employeeMail,
                mailType: 'personal'
             );
         } else if (_selectedSender == 'Custom Email') {
             success = await service.sendCustomBulkEmail(
                subject: subject,
                body: _bodyController.text,
                recipients: recipientEmails,
                employeeMail: employeeMail,
                mailType: 'personal'
             );
         }

         if (mounted) {
             if (success) {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email Sent Successfully!")));
             } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send email. Check logs.")));
             }
         }
     } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error sending email: $e")));
     } finally {
         if (mounted) setState(() => _isLoadingAuth = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Blinkit-style roundness
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         "Send Email",
                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
                       ),
                       const SizedBox(height: 4),
                       const SizedBox(height: 4),
                       Text(
                         "${_leadRecipients.length + _manualRecipients.length} recipients selected",
                         style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
                       ),
                     ],
                   ),
                   IconButton(
                     onPressed: () => Navigator.pop(context),
                     icon: Container(
                       padding: const EdgeInsets.all(4),
                       decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                       child: const Icon(Icons.close, size: 18),
                     ),
                   )
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipients Chip View (Collapsible logic could be added here, keeping simple for now)
                    Text("To", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                                ..._leadRecipients.map((lead) => _buildChip(lead.email, onRemove: () => _removeRecipient(lead: lead))),
                                ..._manualRecipients.map((email) => _buildChip(email, onRemove: () => _removeRecipient(email: email))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                                Expanded(
                                    child: TextField(
                                        controller: _manualRecipientController,
                                        decoration: const InputDecoration(
                                            hintText: "Add email address",
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                        onSubmitted: (_) => _addManualRecipient(),
                                    ),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.black, size: 20),
                                    onPressed: _addManualRecipient,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                )
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Send By Dropdown
                     Text("Send By", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                     const SizedBox(height: 8),
                     if (_isLoadingAuth)
                        const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                     else if (_senderProfiles.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text("Connect Gmail/Outlook in Settings", style: TextStyle(color: Colors.red[700], fontSize: 13, fontWeight: FontWeight.w500))),
                              IconButton(
                                icon: Icon(Icons.refresh, color: Colors.red[700], size: 20),
                                onPressed: _checkAuthStatus,
                                tooltip: "Retry Connection",
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              )
                            ],
                          ),
                        )
                     else 
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSender,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black)),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          items: _senderProfiles.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                          onChanged: (val) {
                             setState(() {
                                 _selectedSender = val;
                             });
                          },
                        ),
                    
                    const SizedBox(height: 20),
                    
                    // Employee Mail
                    if (_selectedSender != null) ...[
                      Text("Employee Email", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.transparent)
                        ),
                        child: TextField(
                           controller: _employeeEmailController,
                           style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500, fontSize: 14),
                           decoration: const InputDecoration(
                               border: InputBorder.none,
                               contentPadding: EdgeInsets.zero
                           ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Templates Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text("Use Template", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          if (_selectedTemplateId != null)
                             TextButton(
                                 onPressed: () {
setState(() {
                                          _selectedTemplateId = null;
                                          _subjectController.clear();
                                          _bodyController.clear();
                                      });
                                 },
                                 style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                 child: Text("Clear", style: TextStyle(fontSize: 12, color: Colors.red[400])),
                             )
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                        initialValue: _selectedTemplateId,
                        hint: const Text("Select a template"),
                        isExpanded: true,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black)),
                        ),
                        items: ref.watch(templateProvider).templates.map((t) => DropdownMenuItem(
                            value: t.id, 
                            child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1),
                        )).toList(),
                        onChanged: (val) {
                            if (val != null) {
                                final t = ref.read(templateProvider).templates.firstWhere((x) => x.id == val);
                                setState(() {
                                    _selectedTemplateId = val;
                                    _subjectController.text = t.subject;
                                    _bodyController.text = t.body;
                                    _saveAsTemplate = false;
                                });
                                _webViewController?.evaluateJavascript(source: "setHtml('${_escapeJsString(t.body)}');");
                            }
                        },
                    ),
                    const SizedBox(height: 16),

                    // Subject
                    Text("Subject", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                       controller: _subjectController,
                       style: const TextStyle(fontWeight: FontWeight.w600),
                       decoration: InputDecoration(
                         hintText: "Enter email subject",
                         hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
                         filled: true,
                         fillColor: Colors.grey[50],
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                         enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black)),
                       ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Message Body Title with visual toggle
                    Text("Message Body", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      height: 360,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Toolbar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.undo, size: 18),
                                    onPressed: _undo,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Undo',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.redo, size: 18),
                                    onPressed: _redo,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Redo',
                                  ),
                                  _FormatDivider(),
                                  IconButton(
                                    icon: const Icon(Icons.format_bold, size: 18),
                                    onPressed: () => _applyFormat('bold'),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Bold',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_italic, size: 18),
                                    onPressed: () => _applyFormat('italic'),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Italic',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_underlined, size: 18),
                                    onPressed: () => _applyFormat('underline'),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Underline',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.title, size: 18),
                                    onPressed: () => _applyFormat('formatBlock', '<h2>'),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Heading',
                                  ), 
                                  IconButton(
                                    icon: const Icon(Icons.palette, size: 18),
                                    onPressed: _showColorPicker,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Color',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.image, size: 18),
                                    onPressed: _uploadAndInsertImage,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Insert Image',
                                  ),
                                  _FormatDivider(),
                                  IconButton(
                                    icon: const Icon(Icons.format_list_bulleted, size: 18),
                                    onPressed: () => _applyFormat('insertUnorderedList'),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Bulleted List',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_list_numbered, size: 18),
                                    onPressed: () => _applyFormat('insertOrderedList'),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Numbered List',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.link, size: 18),
                                    onPressed: _showLinkPicker,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[700],
                                    tooltip: 'Insert Link',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Editor Area using InAppWebView
                          Expanded(
                            child: InAppWebView(
                              initialData: InAppWebViewInitialData(
                                data: getHtmlTemplate(_bodyController.text),
                                mimeType: 'text/html',
                                encoding: 'utf-8',
                              ),
                              initialSettings: InAppWebViewSettings(
                                transparentBackground: true,
                                javaScriptEnabled: true,
                                supportZoom: false,
                                isInspectable: kDebugMode,
                              ),
                              gestureRecognizers: {
                                Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                              },
                              onWebViewCreated: (controller) {
                                _webViewController = controller;
                                controller.addJavaScriptHandler(
                                  handlerName: 'onContentChanged',
                                  callback: (args) {
                                    if (args.isNotEmpty) {
                                      _bodyController.text = args[0] as String;
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    

                    const SizedBox(height: 24),
                    
                    // Save as Template Option
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100)
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 24, width: 24,
                                child: Checkbox(
                                  value: _saveAsTemplate,
                                  onChanged: (val) => setState(() => _saveAsTemplate = val ?? false),
                                  activeColor: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text("Save this email as a new template", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue.shade900))),
                            ],
                          ),
                          if (_saveAsTemplate) ...[
                             const SizedBox(height: 12),
                             TextField(
                               controller: _templateNameController,
                               style: const TextStyle(fontSize: 13),
                               decoration: InputDecoration(
                                 hintText: "Enter Template Name",
                                 hintStyle: TextStyle(color: Colors.blue.shade300),
                                 filled: true,
                                 fillColor: Colors.white,
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade200)),
                                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade200)),
                                 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5)),
                               ),
                             )
                          ]
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text("Powered by TinyMCE", style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)),
                    )
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoadingAuth ? null : _sendEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoadingAuth 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("SEND EMAIL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class FormatButton extends StatelessWidget {
  final IconData icon;
  const FormatButton({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, size: 18, color: Colors.grey[700]),
    );
  }
}

class _FormatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      width: 1,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
