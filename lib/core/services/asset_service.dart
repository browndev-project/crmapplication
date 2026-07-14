import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/asset_model.dart';
import 'r2_service.dart';
import 'dart:io';

final assetServiceProvider = Provider((ref) => AssetService());

class AssetService {
  final _r2Service = R2Service();
  
  Future<List<AssetModel>> fetchAssets() async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/asset/list');
    debugPrint('AssetService: Fetching Assets: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('AssetService: Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List assetsJson = data['data']['assets'] ?? [];
          return assetsJson.map((e) => AssetModel.fromJson(e)).toList();
        }
        return [];
      } else {
        throw 'Failed to fetch assets: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('AssetService Error: $e');
      throw e.toString();
    }
  }

  Future<bool> uploadAsset(PlatformFile file, {required String name, required List<String> tags}) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    // 1. Upload to Cloudflare R2
    String? r2Key;
    try {
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw 'File content not available';
      }

      // Determine content type
      String contentType = 'application/octet-stream';
      final ext = file.extension?.toLowerCase();
      if (ext == 'pdf') {
        contentType = 'application/pdf';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'doc' || ext == 'docx') {
        contentType = 'application/msword';
      }

      // Use a unique name for R2 to avoid collisions
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      r2Key = await _r2Service.uploadFile(bytes, uniqueFileName, contentType);
      debugPrint('AssetService: R2 Upload Success, Key: $r2Key');
    } catch (e) {
      debugPrint('AssetService: R2 Upload Failed: $e');
      throw 'Cloudflare R2 Upload Failed: $e';
    }

    // 2. Notify Backend
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/asset/create');
    debugPrint('AssetService: Creating Asset record at $uri');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'name': name,
          'tags': tags,
          'r2Key': r2Key,
          'fileType': file.extension ?? '',
          'size': file.size,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('AssetService: Backend Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
         throw 'Failed to create asset record: ${response.body}';
      }
    } catch (e) {
      debugPrint('AssetService Backend Error: $e');
      throw e.toString();
    }
  }

  Future<bool> deleteAsset(String id) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/asset/$id');
    debugPrint('AssetService: Deleting Asset: $uri');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('AssetService: Delete Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw 'Failed to delete asset: ${response.body}';
      }
    } catch (e) {
      debugPrint('AssetService Delete Error: $e');
      throw e.toString();
    }
  }
}
