import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/message.dart';

class ApiService {
  final String apiKey;
  
  ApiService(this.apiKey);
  
  Future<String?> sendMessage({
    required List<Message> history,
    required String newPrompt,
    List<String>? attachedImages,
  }) async {
    try {
      // 构建消息历史
      final messages = <Map<String, dynamic>>[];
      
      for (final msg in history) {
        if (msg.isUser) {
          if (msg.attachedImages != null && msg.attachedImages!.isNotEmpty) {
            messages.add({
              'role': 'user',
              'content': [
                if (msg.text != null && msg.text!.isNotEmpty)
                  {'type': 'text', 'text': msg.text},
                ...msg.attachedImages!.map((img) => {
                  'type': 'image_url',
                  'image_url': {'url': img}
                }),
              ],
            });
          } else if (msg.text != null && msg.text!.isNotEmpty) {
            messages.add({
              'role': 'user',
              'content': msg.text,
            });
          }
        } else {
          messages.add({
            'role': 'assistant',
            'content': msg.text ?? '',
          });
        }
      }
      
      // 添加新消息
      if (attachedImages != null && attachedImages.isNotEmpty) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': newPrompt},
            ...attachedImages.map((img) => {
              'type': 'image_url',
              'image_url': {'url': img}
            }),
          ],
        });
      } else {
        messages.add({
          'role': 'user',
          'content': newPrompt,
        });
      }
      
      final response = await http.post(
        Uri.parse(AppConfig.apiEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConfig.model,
          'messages': messages,
          'max_tokens': 2048,
        }),
      ).timeout(Duration(seconds: AppConfig.timeout));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        
        // 解析 ![image](URL) 格式
        final match = RegExp(r'!\[.*?\]\((https?://[^)]+)\)').firstMatch(content);
        return match?.group(1);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['error']?['message'] ?? 'API请求失败');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请检查网络连接');
      }
      rethrow;
    }
  }
}
