import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../presentation/widgets/in_app_video_player.dart';
import '../../presentation/widgets/full_screen_image_viewer.dart';

class MediaHelper {
  static const String baseUrl = 'https://crm-app-backend-btpi.onrender.com';

  /// Extracts YouTube video ID from various URL formats.
  static String? extractYouTubeId(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtu.be/')) {
      return url.split('youtu.be/').last.split('?').first.split('/').first;
    } else if (lower.contains('v=')) {
      return url.split('v=').last.split('&').first.split('/').first;
    } else if (lower.contains('embed/')) {
      return url.split('embed/').last.split('?').first.split('/').first;
    } else if (lower.contains('shorts/')) {
      return url.split('shorts/').last.split('?').first.split('/').first;
    } else if (lower.contains('live/')) {
      return url.split('live/').last.split('?').first.split('/').first;
    }
    return null;
  }

  /// Returns YouTube thumbnail URL for a video ID (or null).
  static String? youTubeThumbnail(String? videoId) {
    if (videoId == null || videoId.isEmpty) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Resolves relative backend paths and external links (e.g. YouTube) correctly.
  static String getMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    
    final trimmed = path.trim();
    final lower = trimmed.toLowerCase();
    
    // 1. YouTube url scheme normalization
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        return 'https://$trimmed';
      }
      return trimmed;
    }
    
    // 2. Absolute URL check
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    
    // 3. Prepend backend base URL for relative paths
    final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$baseUrl/$cleanPath';
  }

  static bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.contains('.jpg?') ||
        lower.contains('.jpeg?') ||
        lower.contains('.png?') ||
        lower.contains('.webp?');
  }

  static bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.contains('.mp4?') ||
        lower.contains('/video');
  }

  /// Securely launches a media URL using error-resilient methods.
  static Future<void> launchMediaUrl(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No link provided")),
      );
      return;
    }

    final resolvedUrl = getMediaUrl(url);
    final lower = resolvedUrl.toLowerCase();

    if (_isImageUrl(lower)) {
      FullScreenImageViewer.show(context, resolvedUrl);
      return;
    }

    if (_isVideoUrl(lower)) {
      InAppVideoPlayer.show(context, resolvedUrl);
      return;
    }

    final uri = Uri.parse(resolvedUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint("MediaHelper: Error launching URL $resolvedUrl: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open media: $resolvedUrl"),
            action: SnackBarAction(
              label: 'Copy Link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: resolvedUrl));
              },
            ),
          ),
        );
      }
    }
  }
}
