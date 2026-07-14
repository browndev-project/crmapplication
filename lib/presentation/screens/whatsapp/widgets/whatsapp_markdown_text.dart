import 'package:flutter/material.dart';

class WhatsAppMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const WhatsAppMarkdownText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: style,
        children: _parseWhatsAppText(text, style),
      ),
    );
  }

  List<TextSpan> _parseWhatsAppText(String text, TextStyle baseStyle) {
    final pattern = RegExp(r'(\*([^*]+)\*)|(_([^_]+)_)|(~([^~]+)~)|(`([^`]+)`)');
    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.addAll(_parseInlineContent(text.substring(lastMatchEnd, match.start), baseStyle));
      }

      TextStyle? formattedStyle;
      String? matchedText;

      if (match.group(1) != null) {
        formattedStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);
        matchedText = match.group(2);
      } else if (match.group(3) != null) {
        formattedStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
        matchedText = match.group(4);
      } else if (match.group(5) != null) {
        formattedStyle = baseStyle.copyWith(decoration: TextDecoration.lineThrough);
        matchedText = match.group(6);
      } else if (match.group(7) != null) {
        formattedStyle = baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.withValues(alpha: 0.2),
        );
        matchedText = match.group(8);
      }

      if (matchedText != null && formattedStyle != null) {
        spans.addAll(_parseInlineContent(matchedText, formattedStyle));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.addAll(_parseInlineContent(text.substring(lastMatchEnd), baseStyle));
    }

    return spans;
  }

  List<TextSpan> _parseInlineContent(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final combinedPattern = RegExp(r'(https?://[^\s]+)|([\w.+-]+@[\w-]+\.[\w.-]+)|(\+?\d[\d\s\-().]{6,}\d)');
    int lastEnd = 0;

    for (final match in combinedPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }

      final matchedText = match.group(0) ?? '';
      spans.add(TextSpan(
        text: matchedText,
        style: baseStyle.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    if (spans.isEmpty && text.isNotEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    return spans;
  }
}
