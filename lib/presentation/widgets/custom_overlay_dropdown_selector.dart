import 'package:flutter/material.dart';

/// A professional, reusable overlay dropdown selector.
/// Supports single-select (default) and multi-select modes.
/// Shows a floating dropdown above the input field; if there is not enough
/// vertical space it flips to show below.
///
/// Parameters:
/// - [items] : Full list of available string options.
/// - [selectedItems] : Currently selected values (for multi-select) or a
///   single‑item list for single‑select.
/// - [onChanged] : Callback with the new list of selected items.
/// - [label] : Input label.
/// - [placeholder] : Text shown when nothing is selected.
/// - [multiSelect] : Enables multi‑select UI with chips.
/// - [allowCustom] : Allows the user to add a new item not present in
///   [items] by typing and pressing Enter.
class CustomOverlayDropdownSelector extends StatefulWidget {
  final List<String> items;
  final List<String> selectedItems;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String placeholder;
  final bool multiSelect;
  final bool allowCustom;

  const CustomOverlayDropdownSelector({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
    this.label = '',
    this.placeholder = '',
    this.multiSelect = false,
    this.allowCustom = false,
  });

  @override
  State<CustomOverlayDropdownSelector> createState() => _CustomOverlayDropdownSelectorState();
}

class _CustomOverlayDropdownSelectorState extends State<CustomOverlayDropdownSelector> with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<String> _tempSelected = [];
  String _search = '';
  
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedItems);
    if (!widget.multiSelect && widget.selectedItems.isNotEmpty) {
      _controller.text = widget.selectedItems.first;
    }
    _focusNode.addListener(_handleFocusChange);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant CustomOverlayDropdownSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedItems != widget.selectedItems) {
      _tempSelected = List.from(widget.selectedItems);
      if (!widget.multiSelect && widget.selectedItems.isNotEmpty) {
        _controller.text = widget.selectedItems.first;
      } else if (!widget.multiSelect) {
        _controller.clear();
      }
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _animationController.forward();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _animationController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _search = '';
    setState(() {});
  }
  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    const maxHeight = 300.0;
    final bool openAbove = offset.dy > screenHeight / 2;
    final double top = openAbove ? offset.dy - maxHeight : offset.dy + size.height;

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        width: size.width,
        top: top,
        height: maxHeight,
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _buildOverlayList(),
                ),
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: TextField(
                    autofocus: true,
                    controller: TextEditingController(text: _search),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _search = v;
                      });
                    },
                    onSubmitted: (v) {
                      if (widget.allowCustom && v.isNotEmpty) {
                        _addCustom(v);
                      }
                    },
                  ),
                ),
                if (widget.multiSelect)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_tempSelected.length} selected',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _tempSelected.clear());
                            widget.onChanged(_tempSelected);
                          },
                          child: const Text('CLEAR ALL', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayList() {
    final filteredItems = widget.items.where((i) {
      final lower = i.toLowerCase();
      final query = _search.toLowerCase();
      return query.isEmpty || lower.contains(query);
    }).toList();

    if (filteredItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: Colors.grey, size: 32),
            SizedBox(height: 8),
            Text('No items found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isSelected = _tempSelected.contains(item);

        return InkWell(
          onTap: () {
            if (widget.multiSelect) {
              setState(() {
                if (isSelected) {
                  _tempSelected.remove(item);
                } else {
                  _tempSelected.add(item);
                }
                widget.onChanged(List.from(_tempSelected));
              });
            } else {
              _tempSelected = [item];
              _controller.text = item;
              widget.onChanged(_tempSelected);
              _focusNode.unfocus();
            }
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: isSelected ? Colors.grey.shade200 : Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 16, color: Colors.black54),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addCustom(String value) {
    if (!_tempSelected.contains(value)) {
      setState(() {
        _tempSelected.add(value);
      });
    }
    _controller.clear();
    _search = '';
    if (!widget.multiSelect) {
      _controller.text = value;
      widget.onChanged(_tempSelected);
      _focusNode.unfocus();
    }
  }

  void _clearAll() {
    setState(() {
      _tempSelected.clear();
      _controller.clear();
    });
    widget.onChanged(_tempSelected);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayTags = widget.multiSelect && _tempSelected.isNotEmpty;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: Border.all(
                color: _focusNode.hasFocus
                    ? Colors.blue
                    : Colors.grey.shade400,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: _focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: displayTags
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _tempSelected.map((v) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(v, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _tempSelected.remove(v));
                                        widget.onChanged(_tempSelected);
                                      },
                                      child: const Icon(Icons.close, size: 14, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          )
                        : _tempSelected.isNotEmpty && !widget.multiSelect
                            ? Text(
                                _tempSelected.first,
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              )
                            : TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: widget.placeholder,
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onSubmitted: (v) {
                                  if (widget.allowCustom && v.isNotEmpty) _addCustom(v);
                                },
                              ),
                  ),
                  if (_tempSelected.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAll,
                      child: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
