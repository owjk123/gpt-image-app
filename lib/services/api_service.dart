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
            final content = <Map<String, dynamic>>[];
            if (msg.text != null && msg.text!.isNotEmpty) {
              content.add({'type': 'text', 'text': msg.text});
            }
            for (final img in msg.attachedImages!) {
              content.add({
                'type': 'image_url',
                'image_url': {'url': img}
              });
            }
            messages.add({'role': 'user', 'content': content});
          } else if (msg.text != null && msg.text!.isNotEmpty) {
            messages.add({'role': 'user', 'content': msg.text});
          }
        } else {
          // AI消息：只保留文本或图片URL，不重复发送
          if (msg.imageUrl != null) {
            // 不需要把AI的图片URL再发回去
            continue;
          } else if (msg.text != null && msg.text!.isNotEmpty) {
            messages.add({'role': 'assistant', 'content': msg.text});
          }
        }
      }
      
      // 添加新消息
      if (attachedImages != null && attachedImages.isNotEmpty) {
        final content = <Map<String, dynamic>>[
          {'type': 'text', 'text': newPrompt}
        ];
        for (final img in attachedImages) {
          content.add({
            'type': 'image_url',
            'image_url': {'url': img}
          });
        }
        messages.add({'role': 'user', 'content': content});
      } else {
        messages.add({'role': 'user', 'content': newPrompt});
      }
      
      print('=== API Request ===');
      print('Endpoint: ${AppConfig.apiEndpoint}');
      print('Model: ${AppConfig.model}');
      print('Messages count: ${messages.length}');
      
      final response = await http.post(
        Uri.parse(AppConfig.apiEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConfig.model,
          'messages': messages,
        }),
      ).timeout(Duration(seconds: AppConfig.timeout));
      
      print('=== API Response ===');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (data['choices'] == null || (data['choices'] as List).isEmpty) {
          throw Exception('API返回数据格式错误：无choices');
        }
        
        final content = data['choices'][0]['message']['content'];
        print('Content type: ${content.runtimeType}');
        print('Content: $content');
        
        if (content == null) {
          throw Exception('API返回content为空');
        }
        
        final contentStr = content.toString();
        
        // 解析 ![image](URL) 格式
        final match = RegExp(r'!\[.*?\]\((https?://[^)]+)\)').firstMatch(contentStr);
        if (match != null) {
          final url = match.group(1);
          print('Extracted URL: $url');
          return url;
        }
        
        // 尝试直接URL
        final urlMatch = RegExp(r'https?://\S+\.(png|jpg|jpeg|webp)').firstMatch(contentStr);
        if (urlMatch != null) {
          print('Direct URL: ${urlMatch.group(0)}');
          return urlMatch.group(0);
        }
        
        // 尝试base64
        if (contentStr.contains('data:image')) {
          print('Found base64 image');
          return contentStr;
        }
        
        print('No image URL found in response');
        throw Exception('未找到图片URL，响应: ${contentStr.substring(0, contentStr.length > 100 ? 100 : contentStr.length)}');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMsg = error['error']?['message'] ?? 'API请求失败 (${response.statusCode})';
        print('API Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('=== Exception ===');
      print(e.toString());
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw Exception('请求超时，请检查网络连接');
      }
      rethrow;
    }
  }
}
