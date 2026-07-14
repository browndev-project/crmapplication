import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/property_provider.dart';

class AmenitiesTagInput extends ConsumerStatefulWidget {
  final List<String> selectedAmenities;
  final ValueChanged<List<String>> onChanged;
  final bool isDark;

  const AmenitiesTagInput({
    super.key,
    required this.selectedAmenities,
    required this.onChanged,
    this.isDark = false,
  });

  @override
  ConsumerState<AmenitiesTagInput> createState() => _AmenitiesTagInputState();
}

class _AmenitiesTagInputState extends ConsumerState<AmenitiesTagInput> {
  final TextEditingController _customAmenityController = TextEditingController();

  @override
  void dispose() {
    _customAmenityController.dispose();
    super.dispose();
  }

  void _toggleMasterAmenity(String amenity) {
    if (widget.selectedAmenities.contains(amenity)) {
      widget.onChanged(widget.selectedAmenities.where((a) => a != amenity).toList());
    } else {
      widget.onChanged([...widget.selectedAmenities, amenity]);
    }
  }

  void _addCustomAmenity() {
    final val = _customAmenityController.text.trim();
    if (val.isNotEmpty && !widget.selectedAmenities.contains(val)) {
      widget.onChanged([...widget.selectedAmenities, val]);
      _customAmenityController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(amenitiesProvider);
    final allAmenities = amenitiesAsync.when(
      data: (a) => a,
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    if (allAmenities.isEmpty && widget.selectedAmenities.isEmpty) {
      return const SizedBox(
        height: 40,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final customAmenities = widget.selectedAmenities.where((a) => !allAmenities.contains(a)).toList();
    final combinedAmenities = [...allAmenities, ...customAmenities];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Amenities",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: combinedAmenities.map((amenity) {
            final isSelected = widget.selectedAmenities.contains(amenity);
            return FilterChip(
              label: Text(
                amenity,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _toggleMasterAmenity(amenity),
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              backgroundColor: widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey[100],
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _customAmenityController,
                  decoration: InputDecoration(
                    hintText: "Add custom amenity...",
                    hintStyle: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[500] : Colors.grey[400]),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: widget.isDark ? Colors.grey[500]! : Colors.grey[400]!),
                    ),
                  ),
                  style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white : Colors.black),
                  onSubmitted: (_) => _addCustomAmenity(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _addCustomAmenity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDark ? Colors.grey[800] : Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text("Add", style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
