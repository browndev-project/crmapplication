import 'package:flutter/material.dart';

class HorizontalPeekCardList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double height;
  final double? cardWidth;
  final double? visibleFullCount; // e.g. 2.35 means 2 full cards + 1 cut-off card at right edge
  final EdgeInsetsGeometry padding;
  final double spacing;

  const HorizontalPeekCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 250,
    this.cardWidth,
    this.visibleFullCount = 2.35, // 2 full cards + 1 partially cut card at right edge by default
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 12.0,
  });

  @override
  State<HorizontalPeekCardList> createState() => _HorizontalPeekCardListState();
}

class _HorizontalPeekCardListState extends State<HorizontalPeekCardList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // Strictly force scroll position to start at offset 0.0 (Product #1 on far left)
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
    if (widget.itemCount == 0) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate card width dynamically to guarantee right-edge cut-off peek effect starting at product #1
    final calculatedWidth = widget.cardWidth ??
        ((screenWidth - 32 - ((widget.visibleFullCount ?? 2.35) - 1) * widget.spacing) /
            (widget.visibleFullCount ?? 2.35));

    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // Pure manual user dragging/scrolling only
        padding: widget.padding,
        itemCount: widget.itemCount,
        itemBuilder: (context, index) {
          final isLast = index == widget.itemCount - 1;
          return Container(
            width: calculatedWidth,
            margin: EdgeInsets.only(right: isLast ? 0 : widget.spacing),
            child: widget.itemBuilder(context, index),
          );
        },
      ),
    );
  }
}
