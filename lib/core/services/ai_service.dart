import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';

class AiService {
  Future<String?> _getAccessToken() async {
    final box = await Hive.openBox('authBox');
    return box.get('accessToken');
  }

  static const String _systemPrompt = 'You are an expert AI image prompt engineer. Analyze the provided description to determine its subject, context, and intent. Then, generate a highly detailed, photorealistic, and visually stunning image prompt tailored perfectly to that specific subject. Focus on lighting, atmosphere, and 2k resolution quality appropriate for the context. Do not include any text, UI elements, or logos unless explicitly requested in the description. Keep the prompt concise (under 50 words) and ensure it forms a complete sentence without being cut off. Return ONLY the optimized prompt text and nothing else.';

  Future<String> optimizePrompt({
    required String description,
    String? systemPrompt,
  }) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/ai/optimize-prompt');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'description': description,
        'systemPrompt': systemPrompt ?? _systemPrompt,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final nestedData = data['data'] ?? data;
      return nestedData['prompt'] ?? nestedData['data'] ?? '';
    } else {
      throw 'Unable to optimize prompt';
    }
  }

  Future<String> generateImage({
    required String prompt,
    int width = 1024,
    int height = 576,
    bool nologo = true,
  }) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/ai/generate-image');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'prompt': prompt,
        'width': width,
        'height': height,
        'nologo': nologo,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final nestedData = data['data'] ?? data;
      return nestedData['url'] ?? '';
    } else {
      throw 'Image generation failed';
    }
  }

  static Map<String, Map<String, int>> get resolutionPresets => {
    'Landscape (1024 × 576)': {'width': 1024, 'height': 576},
    'Square (1024 × 1024)': {'width': 1024, 'height': 1024},
    'Portrait (576 × 1024)': {'width': 576, 'height': 1024},
    'SD Landscape (768 × 512)': {'width': 768, 'height': 512},
    'HD Landscape (1280 × 720)': {'width': 1280, 'height': 720},
    'Full HD (1920 × 1080)': {'width': 1920, 'height': 1080},
  };
}