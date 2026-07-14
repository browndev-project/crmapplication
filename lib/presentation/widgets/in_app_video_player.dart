import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppVideoPlayer extends StatefulWidget {
  final String url;

  const InAppVideoPlayer({super.key, required this.url});

  static void show(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Video Player',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return InAppVideoPlayer(url: url);
      },
    );
  }

  @override
  State<InAppVideoPlayer> createState() => _InAppVideoPlayerState();
}

class _InAppVideoPlayerState extends State<InAppVideoPlayer> {
  bool _isLoading = true;
  String? _error;
  bool _isHtmlVideo = false;
  String? _videoHtml;
  String? _embedUrl;

  late final String _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = _normalizeUrl(widget.url);
    _prepareVideo();
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return trimmed;
    return 'https://$trimmed';
  }

  void _prepareVideo() {
    final lower = _resolvedUrl.toLowerCase();

    // YouTube link handler
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      String? videoId;
      if (lower.contains('youtu.be/')) {
        videoId = _resolvedUrl.split('youtu.be/').last.split('?').first.split('/').first;
      } else if (lower.contains('v=')) {
        videoId = _resolvedUrl.split('v=').last.split('&').first.split('/').first;
      } else if (lower.contains('embed/')) {
        videoId = _resolvedUrl.split('embed/').last.split('?').first.split('/').first;
      } else if (lower.contains('shorts/')) {
        videoId = _resolvedUrl.split('shorts/').last.split('?').first.split('/').first;
      } else if (lower.contains('live/')) {
        videoId = _resolvedUrl.split('live/').last.split('?').first.split('/').first;
      }

      if (videoId != null && videoId.isNotEmpty) {
        _embedUrl = 'https://www.youtube.com/watch?v=$videoId';
      }
      return;
    }

    // Direct video link - wrap in HTML5 video with autoplay
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') || lower.contains('.mp4?') || lower.contains('/video')) {
      _isHtmlVideo = true;
      _videoHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body { margin: 0; padding: 0; background-color: black; display: flex; justify-content: center; align-items: center; height: 100vh; overflow: hidden; }
            video { width: 100%; height: 100%; max-height: 100vh; object-fit: contain; }
          </style>
        </head>
        <body>
          <video controls autoplay playsinline>
            <source src="$_resolvedUrl" type="video/mp4">
            Your browser does not support the video tag.
          </video>
        </body>
        </html>
      ''';
      return;
    }

    _embedUrl = widget.url;
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(_resolvedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrlValid = _resolvedUrl.isNotEmpty && _resolvedUrl.startsWith('https://');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            isUrlValid
                ? (_isHtmlVideo && _videoHtml != null
                    ? InAppWebView(
                        initialData: InAppWebViewInitialData(
                          data: _videoHtml!,
                          mimeType: 'text/html',
                          encoding: 'utf-8',
                          baseUrl: WebUri(_resolvedUrl.contains('youtube.com') || _resolvedUrl.contains('youtu.be')
                              ? 'https://www.youtube.com'
                              : _resolvedUrl),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          mediaPlaybackRequiresUserGesture: false,
                          allowsInlineMediaPlayback: true,
                          useHybridComposition: true,
                          userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                        ),
                        onLoadStart: (controller, url) {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                        },
                        onLoadStop: (controller, url) {
                          setState(() {
                            _isLoading = false;
                          });
                        },
                        onReceivedError: (controller, request, error) {
                          setState(() {
                            _isLoading = false;
                            _error = error.description;
                          });
                        },
                        onReceivedHttpError: (controller, request, errorResponse) {
                          setState(() {
                            _isLoading = false;
                            _error = "HTTP error: ${errorResponse.statusCode}";
                          });
                        },
                      )
                    : InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(_embedUrl ?? _resolvedUrl),
                          headers: {
                            if (_embedUrl != null && _embedUrl!.contains('youtube.com'))
                              'Referer': 'https://www.youtube.com/',
                          },
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          mediaPlaybackRequiresUserGesture: false,
                          allowsInlineMediaPlayback: true,
                          useHybridComposition: true,
                          userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                        ),
                        onLoadStart: (controller, url) {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                        },
                        onLoadStop: (controller, url) {
                          setState(() {
                            _isLoading = false;
                          });
                        },
                        onReceivedError: (controller, request, error) {
                          setState(() {
                            _isLoading = false;
                            _error = error.description;
                          });
                        },
                        onReceivedHttpError: (controller, request, errorResponse) {
                          setState(() {
                            _isLoading = false;
                            _error = "HTTP error: ${errorResponse.statusCode}";
                          });
                        },
                      ))
                : const Center(
                    child: Text(
                      "Invalid video URL",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),

            // Loading indicator
            if (_isLoading && isUrlValid)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            // Error display
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "Failed to load video:\n$_error",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _openInBrowser,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text("Open in Browser"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Close button + External Browser fallback at top right
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
                      onPressed: _openInBrowser,
                      tooltip: 'Open in Browser',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
