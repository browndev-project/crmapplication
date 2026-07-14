import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/lead_document_provider.dart';
import '../../../data/models/lead_document_model.dart';

class DocumentFormCreateDialog extends ConsumerStatefulWidget {
  final DocumentForm? existingForm;
  const DocumentFormCreateDialog({super.key, this.existingForm});

  @override
  ConsumerState<DocumentFormCreateDialog> createState() => _DocumentFormCreateDialogState();
}

class _DocumentFormCreateDialogState extends ConsumerState<DocumentFormCreateDialog> {
  final _nameController = TextEditingController();
  final List<DocumentFormField> _fields = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingForm != null) {
      _nameController.text = widget.existingForm!.name;
      _fields.addAll(widget.existingForm!.fields);
    } else {
      _fields.add(DocumentFormField(label: '', required: true));
    }
  }

  void _addField() {
    setState(() {
      _fields.add(DocumentFormField(label: '', required: true));
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty || _fields.isEmpty || _fields.any((f) => f.label.isEmpty)) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool success;
      if (widget.existingForm != null) {
        success = await ref.read(documentFormsProvider.notifier).updateForm(
          widget.existingForm!.id,
          _nameController.text,
          _fields,
        );
      } else {
        success = await ref.read(documentFormsProvider.notifier).createForm(
          _nameController.text,
          _fields,
        );
      }

      if (success && mounted) {
        Navigator.pop(context);
      } else {
        throw 'Failed to save form template';
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.existingForm != null ? 'Edit Document Form' : 'Create Document Form', 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Form Name',
                hintText: 'e.g. Standard Onboarding',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fields', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addField,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ADD FIELD'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _fields.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (val) => _fields[index] = DocumentFormField(label: val, required: _fields[index].required),
                                decoration: InputDecoration(
                                  hintText: 'Field Label',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                controller: TextEditingController(text: _fields[index].label)..selection = TextSelection.fromPosition(TextPosition(offset: _fields[index].label.length)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeField(index),
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _fields[index].required,
                              onChanged: (val) {
                                setState(() {
                                  _fields[index] = DocumentFormField(label: _fields[index].label, required: val ?? false);
                                });
                              },
                            ),
                            const Text('Required', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.existingForm != null ? 'UPDATE' : 'CREATE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
