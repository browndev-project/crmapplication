import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/lead_document_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../../core/constants/permission_constants.dart';
import 'document_form_create_dialog.dart';

class RequestDocumentsDialog extends ConsumerWidget {
  final String leadId;
  const RequestDocumentsDialog({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formsAsync = ref.watch(documentFormsProvider);
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Request Documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                if (permissions.hasPermission(PermissionModules.LEAD_DOCS_FORM_CREATE, userRole: userRole))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const DocumentFormCreateDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('CREATE NEW TEMPLATE', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(documentFormsProvider.notifier).fetchForms(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('REFRESH LIST'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            formsAsync.when(
              data: (forms) {
                if (forms.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No form templates found', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: forms.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final form = forms[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(form.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Row(
                                  children: [
                                    if (permissions.hasPermission(PermissionModules.LEAD_DOCS_FORM_EDIT, userRole: userRole))
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => DocumentFormCreateDialog(existingForm: form),
                                          );
                                        },
                                      ),
                                    if (permissions.hasPermission(PermissionModules.LEAD_DOCS_FORM_DELETE, userRole: userRole))
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                        onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Form?'),
                                            content: const Text('Are you sure you want to delete this form template?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          ref.read(documentFormsProvider.notifier).deleteForm(form.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: form.fields.map((f) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  '${f.label}${f.required ? ' *' : ''}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final link = 'https://trevion.browndevs.com/public-doc-form?leadId=$leadId&formId=${form.id}';
                                  Clipboard.setData(ClipboardData(text: link));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Request link copied to clipboard!'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      backgroundColor: Colors.green.shade700,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('COPY SUBMISSION LINK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade800,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.blue.shade100),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
