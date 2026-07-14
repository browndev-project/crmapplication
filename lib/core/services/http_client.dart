import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as origin_http;

// Re-export HTTP classes and methods from the package so the services can use them unmodified
export 'package:http/http.dart'
    show MultipartRequest, MultipartFile, Response, Client;

Future<void> Function()? onUnauthorized;

/// Validates the API response, extracting any backend-supplied error messages when the request fails.
void _validateResponse(origin_http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return;
  }

  if (response.statusCode == 401 || response.statusCode == 403) {
    onUnauthorized?.call();
  }

  // Parse friendly error messages according to backend structure priority:
  // 1. data.message
  // 2. data.error or data.err
  // 3. message field or fallback to status
  String? friendlyMessage;
  if (response.body.isNotEmpty) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        friendlyMessage =
            decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            decoded['err']?.toString() ??
            decoded['msg']?.toString();
      }
    } catch (_) {
      // Body is not valid JSON, ignore and fallback
    }
  }

  // Fallback chain
  final message =
      friendlyMessage ?? response.reasonPhrase ?? 'Something went wrong';
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw 'Session expired. Please log in again.';
  }
  throw message;
}

Map<String, String> _injectHeaders(Map<String, String>? headers) {
  final Map<String, String> newHeaders = headers != null
      ? Map.from(headers)
      : {};
  newHeaders['Bypass-Tunnel-Reminder'] = 'true';
  return newHeaders;
}

/// Wrapped standard GET request
Future<origin_http.Response> get(
  Uri url, {
  Map<String, String>? headers,
}) async {
  final response = await origin_http.get(url, headers: _injectHeaders(headers));
  _validateResponse(response);
  return response;
}

/// Wrapped standard POST request
Future<origin_http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  final response = await origin_http.post(
    url,
    headers: _injectHeaders(headers),
    body: body,
    encoding: encoding,
  );
  _validateResponse(response);
  return response;
}

/// Wrapped standard PUT request
Future<origin_http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  final response = await origin_http.put(
    url,
    headers: _injectHeaders(headers),
    body: body,
    encoding: encoding,
  );
  _validateResponse(response);
  return response;
}

/// Wrapped standard PATCH request
Future<origin_http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  debugPrint('===== CUSTOM PATCH: about to call origin_http.patch =====');
  final response = await origin_http.patch(
    url,
    headers: _injectHeaders(headers),
    body: body,
    encoding: encoding,
  );
  debugPrint(
    '===== CUSTOM PATCH: origin_http.patch returned, status ${response.statusCode} =====',
  );
  _validateResponse(response);
  debugPrint('===== CUSTOM PATCH: _validateResponse passed =====');
  return response;
}

/// Wrapped standard DELETE request
Future<origin_http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  final response = await origin_http.delete(
    url,
    headers: _injectHeaders(headers),
    body: body,
    encoding: encoding,
  );
  _validateResponse(response);
  return response;
}
