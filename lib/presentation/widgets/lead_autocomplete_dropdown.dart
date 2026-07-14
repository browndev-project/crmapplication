import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/lead_model.dart';
import '../../core/services/lead_service.dart';

class LeadAutocompleteDropdown extends StatefulWidget {
  final Lead? initialLead;
  final Function(Lead? lead) onLeadSelected;
  final bool enabled;

  const LeadAutocompleteDropdown({
    super.key,
    this.initialLead,
    required this.onLeadSelected,
    this.enabled = true,
  });

  @override
  State<LeadAutocompleteDropdown> createState() => _LeadAutocompleteDropdownState();
}

class _LeadAutocompleteDropdownState extends State<LeadAutocompleteDropdown> {
  final LeadService _leadService = LeadService();
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  List<Lead> _suggestions = [];
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  Lead? _selectedLead;

  @override
  void initState() {
    super.initState();
    _selectedLead = widget.initialLead;
    if (_selectedLead != null) {
      _searchController.text = _formatLeadDisplay(_selectedLead!);
    }
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        if (widget.enabled) {
          _showOverlay();
          if (_searchController.text.isEmpty) {
            _fetchSuggestions('');
          }
        }
      } else {
        _hideOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant LeadAutocompleteDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLead != oldWidget.initialLead) {
      setState(() {
        _selectedLead = widget.initialLead;
        if (_selectedLead != null) {
          _searchController.text = _formatLeadDisplay(_selectedLead!);
        } else {
          _searchController.clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _searchController.dispose();
    _hideOverlay();
    super.dispose();
  }

  String _formatLeadDisplay(Lead lead) {
    if (lead.phoneNo.isNotEmpty) {
      return '${lead.name} (${lead.phoneNo})';
    } else if (lead.email.isNotEmpty) {
      return '${lead.name} (${lead.email})';
    }
    return lead.name;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _overlayEntry?.markNeedsBuild();

    try {
      final results = await _leadService.searchLeads(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
        _overlayEntry?.markNeedsBuild();
      }
    } catch (e) {
      debugPrint('Error searching leads: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _focusNode.unfocus();
                _hideOverlay();
              },
            ),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                            ),
                          ),
                        )
                      : _suggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Text(
                                'No matching leads found',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            )
                          : Scrollbar(
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: _suggestions.length,
                                itemBuilder: (context, index) {
                                  final lead = _suggestions[index];
                                  return InkWell(
                                    onTap: () => _selectLead(lead),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        border: index < _suggestions.length - 1
                                            ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatLeadDisplay(lead),
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                          ),
                                          if (lead.company != null && lead.company!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Company: ${lead.company}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectLead(Lead lead) {
    setState(() {
      _selectedLead = lead;
      _searchController.text = _formatLeadDisplay(lead);
      _suggestions.clear();
    });
    widget.onLeadSelected(lead);
    _focusNode.unfocus();
    _hideOverlay();
  }

  void _clearSelection() {
    setState(() {
      _selectedLead = null;
      _searchController.clear();
      _suggestions.clear();
    });
    widget.onLeadSelected(null);
    _focusNode.unfocus();
    _hideOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _searchController,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: "Link to Lead (Optional)",
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          hintText: "Search lead to pre-fill details...",
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          suffixIcon: _selectedLead != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: _clearSelection,
                )
              : const Icon(Icons.arrow_drop_down, color: Colors.black54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
