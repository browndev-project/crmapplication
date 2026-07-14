import 'package:flutter/material.dart';

class CitySearchField extends StatefulWidget {
  final List<String> allCities;
  final String? selectedCity;
  final ValueChanged<String?> onChanged;
  final String label;
  final String hintText;

  const CitySearchField({
    super.key,
    required this.allCities,
    this.selectedCity,
    required this.onChanged,
    this.label = 'City',
    this.hintText = 'Select City',
  });

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _customCities = [];
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selectedCity ?? '';
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant CitySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = widget.selectedCity ?? '';
    if (nextValue != _controller.text && !_focusNode.hasFocus) {
      _controller.text = nextValue;
    }
    if (oldWidget.allCities != widget.allCities) {
      _refreshOverlay();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _display(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map(
          (w) =>
              w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  String _normalize(String text) => text.trim().toLowerCase();

  List<String> _allOptions() {
    final seen = <String>{};
    final options = <String>[];
    for (final raw in [...widget.allCities, ..._customCities]) {
      final city = raw.trim();
      if (city.isEmpty) continue;
      final key = _normalize(city);
      if (seen.add(key)) options.add(city);
    }
    options.sort((a, b) => _display(a).compareTo(_display(b)));
    return options;
  }

  List<String> _filteredOptions() {
    final query = _normalize(_controller.text);
    final options = _allOptions();
    if (query.isEmpty) return options;
    return options.where((city) => _normalize(city).contains(query)).toList();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 120), _removeOverlay);
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _refreshOverlay();
      return;
    }
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _refreshOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectCity(String city) {
    final value = city.trim();
    if (value.isEmpty) return;
    final exists = _allOptions().any(
      (option) => _normalize(option) == _normalize(value),
    );
    if (!exists) _customCities.add(value);

    _controller.text = value;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    widget.onChanged(value);
    _focusNode.unfocus();
    _removeOverlay();
  }

  void _clearCity() {
    _controller.clear();
    widget.onChanged(null);
    if (_focusNode.hasFocus) _refreshOverlay();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;
    final origin = renderBox.localToGlobal(Offset.zero);
    final availableBelow = screenHeight - origin.dy - size.height - 16;
    final maxHeight = availableBelow.clamp(160.0, 320.0);

    return OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final options = _filteredOptions();
        final typedValue = _controller.text.trim();
        final hasExactTyped = options.any(
          (city) => _normalize(city) == _normalize(typedValue),
        );
        final canUseTyped = typedValue.isNotEmpty && !hasExactTyped;
        final itemCount = options.length + (canUseTyped ? 1 : 0);

        return Positioned.fill(
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: size.width,
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2130) : Colors.white,
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: itemCount == 0
                      ? SizedBox(
                          height: 52,
                          child: Center(
                            child: Text(
                              'No cities found',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            final isCustomRow = canUseTyped && index == 0;
                            final city = isCustomRow
                                ? typedValue
                                : options[index - (canUseTyped ? 1 : 0)];
                            final isSelected =
                                widget.selectedCity != null &&
                                _normalize(widget.selectedCity!) ==
                                    _normalize(city);

                            return InkWell(
                              onTap: () => _selectCity(city),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                color: isSelected
                                    ? (isDark
                                          ? Colors.blue.withValues(alpha: 0.18)
                                          : Colors.grey.shade200)
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isCustomRow ? city : _display(city),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isCustomRow)
                                      Text(
                                        'Use typed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Colors.blue,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        textInputAction: TextInputAction.done,
        onTap: _showOverlay,
        onChanged: (_) {
          _refreshOverlay();
        },
        onSubmitted: _selectCity,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
          ),
          prefixIcon: Icon(
            Icons.location_city_outlined,
            size: 18,
            color: Colors.grey[500],
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                  onPressed: _clearCity,
                  tooltip: 'Clear city',
                )
              : Icon(Icons.arrow_drop_down, size: 22, color: Colors.grey[500]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.blue, width: 1.3),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF25293C) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
