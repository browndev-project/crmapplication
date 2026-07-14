import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'http_client.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class R2Service {
  static const String accessKey = '9af1a95fe877a3c7af1f7ce4b8992d64';
  static const String secretKey = '72bb72e8ece1cd293e1d0218d167d9a90516df2ab09f43c11346ed1a5550928c';
  static const String endpoint = '8c6eab311a04c1dacf150888f2e99f1c.r2.cloudflarestorage.com';
  static const String bucket = 'treviondocs';
  static const String region = 'auto'; // R2 uses 'auto'
  static const String publicBaseUrl = 'https://treviondocs.browndevs.com';
  static const String recordingsFolder = 'call_recordings';

  Future<String?> uploadAudio(File file, String uniqueCallId, {String? companyId, String? userId}) async {
    try {
      final bytes = await file.readAsBytes();
      final extension = file.path.split('.').last;

      final String folderPath = '${companyId ?? "unknown"}/${userId ?? "unknown"}/recording';
      final fileName = '$folderPath/$uniqueCallId.$extension';
      final contentType = 'audio/$extension';

      final key = await uploadFile(bytes, fileName, contentType);
      if (key != null) {
        return '$publicBaseUrl/$fileName';
      }
      return null;
    } catch (e) {
      debugPrint('R2Service: Audio upload error: $e');
      return null;
    }
  }

  Future<String?> uploadBase64Image(String dataUrl, {String? folder}) async {
    try {
      final parts = dataUrl.split(',');
      if (parts.length < 2) return null;
      final meta = parts[0];
      final encoded = parts[1];

      String mime = 'image/jpeg';
      String ext = 'jpg';
      final mimeMatch = RegExp(r'data:([^;]+)').firstMatch(meta);
      if (mimeMatch != null) {
        mime = mimeMatch.group(1) ?? 'image/jpeg';
        ext = mime.split('/').last;
        if (ext.contains('+')) ext = ext.split('+').first;
        if (ext.isEmpty) ext = 'jpg';
      }

      while (encoded.length % 4 != 0) {
        encoded.padRight(encoded.length + 1, '=');
      }
      final bytes = base64Decode(encoded);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueId = '${timestamp}_${DateTime.now().microsecondsSinceEpoch % 1000}';
      final folderPath = folder ?? 'ai-images';
      final fileName = '$folderPath/$uniqueId.$ext';

      final key = await uploadFile(Uint8List.fromList(bytes), fileName, mime);
      if (key != null) {
        return '$publicBaseUrl/$fileName';
      }
      return null;
    } catch (e) {
      debugPrint('R2Service: Base64 image upload error: $e');
      return null;
    }
  }

  Future<String?> uploadFile(Uint8List bytes, String fileName, String contentType) async {
    final datetime = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc());
    final date = datetime.substring(0, 8);
    
    final String key = fileName; // You might want to add a prefix like 'assets/' or a UUID
    final String path = '/$bucket/${key.split('/').map((e) => Uri.encodeComponent(e)).join('/')}';
    
    final payloadHash = sha256.convert(bytes).toString();
    
    final headers = {
      'host': endpoint,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': datetime,
      'content-type': contentType,
    };

    // 1. Create Canonical Request
    final sortedHeaderKeys = headers.keys.toList()..sort();
    final canonicalHeaders = '${sortedHeaderKeys.map((k) => '$k:${headers[k]}').join('\n')}\n';
    final signedHeaders = sortedHeaderKeys.join(';');
    
    final canonicalRequest = [
      'PUT',
      path,
      '', // query string
      canonicalHeaders,
      signedHeaders,
      payloadHash
    ].join('\n');
    
    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    // 2. Create String to Sign
    final credentialScope = '$date/$region/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      datetime,
      credentialScope,
      canonicalRequestHash
    ].join('\n');

    // 3. Calculate Signature
    final signingKey = _deriveSigningKey(secretKey, date, region, 's3');
    final signature = _hmacSha256(signingKey, stringToSign);
    final signatureHex = _toHex(signature);

    // 4. Final Authorization Header
    final authHeader = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signatureHex';
    
    final fullHeaders = {
      ...headers,
      'Authorization': authHeader,
    };

    final url = Uri.parse('https://$endpoint$path');
    debugPrint('R2Service: Uploading to $url');

    int retryCount = 0;
    const int maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final response = await http.put(
          url,
          headers: fullHeaders,
          body: bytes,
        );

        debugPrint('R2Service: Response [${response.statusCode}]: ${response.body}');

        if (response.statusCode == 200) {
          return key;
        } else {
          debugPrint('R2Service: Upload failed (${response.statusCode}), retrying... ($retryCount/$maxRetries)');
        }
      } catch (e) {
        debugPrint('R2Service Error: $e, retrying... ($retryCount/$maxRetries)');
      }
      retryCount++;
      await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
    }
    return null;
  }

  Uint8List _deriveSigningKey(String secret, String date, String region, String service) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secret'), date);
    final kRegion = _hmacSha256(kDate, region);
    final kService = _hmacSha256(kRegion, service);
    final kSigning = _hmacSha256(kService, 'aws4_request');
    return kSigning;
  }

  Uint8List _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(utf8.encode(data)).bytes);
  }

  String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
