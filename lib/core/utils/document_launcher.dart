import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentLauncher {
  static bool _isLaunching = false;

  /// Universal method to launch a secure PDF/image/document URL in the system browser/viewer.
  /// Standardizes loading indicator, repeated-tap disabling, validation, and error reporting.
  static Future<void> launchDocument({
    required BuildContext context,
    required Future<String?> Function() urlFetcher,
    String loadingMessage = 'Opening document...',
  }) async {
    if (_isLaunching) return; // Prevent repeated taps
    _isLaunching = true;

    // 1. Show a small loading overlay or SnackBar with indicator
    ScaffoldMessenger.of(context).clearSnackBars();
    final snackBar = SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Text(loadingMessage),
        ],
      ),
      duration: const Duration(minutes: 5), // Keep open until finished
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      // 2. Fetch the URL
      final url = await urlFetcher();

      // Dismiss the loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      // 3. Validate URL
      if (url == null || url.trim().isEmpty) {
        throw 'Unable to open file: Document URL is empty or unavailable.';
      }

      final trimmedUrl = url.trim();
      if (!trimmedUrl.toLowerCase().startsWith('http://') && !trimmedUrl.toLowerCase().startsWith('https://')) {
        throw 'Unable to open file: Invalid document URL protocol.';
      }

      final uri = Uri.parse(trimmedUrl);

      // 4. Launch URL
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success) {
        throw 'Unable to open file';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        // Display nice, non-raw error messages using standard SnackBar error format
        final errorString = e.toString();
        final displayError = errorString.contains('Unable to open file')
            ? errorString
            : 'Unable to open file: $errorString';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isLaunching = false;
    }
  }
}
