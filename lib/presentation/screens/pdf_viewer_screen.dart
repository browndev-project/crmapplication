import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PDFViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;
  final String? publicUrl;

  const PDFViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.publicUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (publicUrl != null)
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: 'Open in Browser',
              onPressed: () async {
                final uri = Uri.parse(publicUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              Share.shareXFiles([XFile(filePath)], text: title);
            },
          ),
        ],
      ),
      body: SfPdfViewer.file(
        File(filePath),
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      ),
    );
  }
}
