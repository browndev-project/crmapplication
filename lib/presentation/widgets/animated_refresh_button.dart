import 'package:flutter/material.dart';

class AnimatedRefreshButton extends StatefulWidget {
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const AnimatedRefreshButton({
    super.key,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<AnimatedRefreshButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating && !_isRefreshing) {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing || widget.isLoading) return;
    setState(() {
      _isRefreshing = true;
    });
    _controller.repeat();
    try {
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        if (!widget.isLoading) {
          _controller.stop();
          _controller.reset();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _isRefreshing || widget.isLoading;
    return InkWell(
      onTap: active ? null : _handleRefresh,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: active ? 0.6 : 1.0,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.cardColor,
            shape: BoxShape.circle,
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: RotationTransition(
            turns: _controller,
            child: Icon(Icons.refresh, size: 20, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
