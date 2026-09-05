import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Centralized Shimmer Loading Skeleton System for the entire application.
class AppShimmer extends StatelessWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2D3D) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3F4257) : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

/// A basic Shimmer Box block element (rounded rectangle or circle)
class AppShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? margin;

  const AppShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape,
    this.margin,
  });

  const AppShimmerBox.circular({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = const CircleBorder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: ShapeDecoration(
        color: isDark ? const Color(0xFF2A2D3D) : const Color(0xFFE0E0E0),
        shape: shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
      ),
    );
  }
}

/// Reusable List Skeleton Loader (e.g. Leads list, Chat list, Invoices list)
class AppShimmerListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const AppShimmerListSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            height: itemHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const AppShimmerBox.circular(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      AppShimmerBox(width: 160, height: 14, borderRadius: 4),
                      SizedBox(height: 8),
                      AppShimmerBox(width: 220, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reusable Card Skeleton Loader (e.g. Property Cards, Dashboard Analytics Cards)
class AppShimmerCardSkeleton extends StatelessWidget {
  final int itemCount;

  const AppShimmerCardSkeleton({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) {
          return Container(
            height: 180,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppShimmerBox(width: double.infinity, height: 90, borderRadius: 8),
                SizedBox(height: 12),
                AppShimmerBox(width: 180, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                AppShimmerBox(width: 120, height: 12, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reusable Detail Page Skeleton Loader (e.g. Lead Profile, Property Details)
class AppShimmerDetailSkeleton extends StatelessWidget {
  const AppShimmerDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            AppShimmerBox(width: double.infinity, height: 180, borderRadius: 12),
            SizedBox(height: 20),
            AppShimmerBox(width: 200, height: 20, borderRadius: 4),
            SizedBox(height: 10),
            AppShimmerBox(width: 140, height: 14, borderRadius: 4),
            SizedBox(height: 24),
            AppShimmerBox(width: double.infinity, height: 60, borderRadius: 8),
            SizedBox(height: 12),
            AppShimmerBox(width: double.infinity, height: 60, borderRadius: 8),
            SizedBox(height: 12),
            AppShimmerBox(width: double.infinity, height: 60, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Reusable BottomSheet Skeleton Loader
class AppShimmerBottomSheetSkeleton extends StatelessWidget {
  final double height;

  const AppShimmerBottomSheetSkeleton({
    super.key,
    this.height = 320,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Center(
              child: AppShimmerBox(width: 40, height: 4, borderRadius: 2),
            ),
            SizedBox(height: 20),
            AppShimmerBox(width: 180, height: 20, borderRadius: 4),
            SizedBox(height: 16),
            AppShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
            SizedBox(height: 12),
            AppShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
            SizedBox(height: 12),
            AppShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp Chat Messages Specific Skeleton Loader
class WhatsAppMessageListSkeleton extends StatelessWidget {
  const WhatsAppMessageListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (context, index) {
          final isRight = index % 2 == 0;
          return Align(
            alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 220,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Inline Button/Icon Shimmer Loading Indicator
class AppShimmerButtonLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const AppShimmerButtonLoading({
    super.key,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
