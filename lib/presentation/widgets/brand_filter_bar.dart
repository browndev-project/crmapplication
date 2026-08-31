import 'package:flutter/material.dart';

class BrandFilterItem {
  final String id;
  final String label;
  final String? iconUrl;
  final IconData? iconData;
  final Color? color;

  const BrandFilterItem({
    required this.id,
    required this.label,
    this.iconUrl,
    this.iconData,
    this.color,
  });
}

class BrandFilterBar extends StatefulWidget {
  final String selectedId;
  final List<BrandFilterItem> items;
  final ValueChanged<String> onSelected;
  final String allLabel;
  final IconData allIcon;
  final double visibleCount; // e.g. 4.4 means 4 full brands + 1 cut-off brand at right edge

  const BrandFilterBar({
    super.key,
    required this.selectedId,
    required this.items,
    required this.onSelected,
    this.allLabel = 'All',
    this.allIcon = Icons.apps_rounded,
    this.visibleCount = 4.4,
  });

  @override
  State<BrandFilterBar> createState() => _BrandFilterBarState();
}

class _BrandFilterBarState extends State<BrandFilterBar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // Strictly force scroll position to start at offset 0.0 (Brand #1 on far left)
    _scrollController = ScrollController(
      initialScrollOffset: 0.0,
      keepScrollOffset: false,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAllSelected = widget.selectedId.isEmpty || widget.selectedId.toLowerCase() == 'all';

    return SizedBox(
      height: 76,
      child: Row(
        children: [
          // ── 1. Fixed "All" Brand Filter Item (Pinned on the Left) ──
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 10.0),
            child: _buildFilterChip(
              context: context,
              id: 'all',
              label: widget.allLabel,
              isSelected: isAllSelected,
              iconData: widget.allIcon,
              isDark: isDark,
              isFixed: true,
            ),
          ),

          // Vertical divider line between fixed "All" and scrollable brands
          Container(
            height: 36,
            width: 1,
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),

          const SizedBox(width: 10),

          // ── 2. Horizontally Scrollable Remaining Brand Items (Starts at Brand #1 on left) ──
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(), // Manual user scrolling only
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: widget.items.map((item) {
                  final isSelected = widget.selectedId == item.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: _buildFilterChip(
                      context: context,
                      id: item.id,
                      label: item.label,
                      isSelected: isSelected,
                      iconUrl: item.iconUrl,
                      iconData: item.iconData,
                      color: item.color,
                      isDark: isDark,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String id,
    required String label,
    required bool isSelected,
    IconData? iconData,
    String? iconUrl,
    Color? color,
    required bool isDark,
    bool isFixed = false,
  }) {
    final activeColor = color ?? const Color(0xFF7C3AED); // Modern purple theme accent

    return GestureDetector(
      onTap: () => widget.onSelected(id),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? (isDark ? activeColor.withAlpha(40) : activeColor.withAlpha(25))
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              border: Border.all(
                color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.grey[300]!),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Center(
              child: iconUrl != null && iconUrl.isNotEmpty
                  ? Image.network(
                      iconUrl,
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        iconData ?? Icons.category_rounded,
                        size: 20,
                        color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    )
                  : Icon(
                      iconData ?? Icons.category_rounded,
                      size: 22,
                      color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
