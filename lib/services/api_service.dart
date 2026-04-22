import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/message.dart';

class ApiService {
  final String apiKey;
  static const int maxRetries = 3;
  
  ApiService(this.apiKey);
  
  Future<String?> sendMessage({
    required List<Message> history,
    required String newPrompt,
    List<String>? attachedImages,
  }) async {
    Exception? lastError;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('=== API Request (Attempt $attempt/$maxRetries) ===');
        return await _sendRequest(history, newPrompt, attachedImages);
      } catch (e) {
        lastError = Exception(e.toString());
        print('Attempt $attempt failed: $e');
        
        // 如果是最后一次尝试，或者不是网络错误，直接抛出
        if (attempt == maxRetries || !_isRetryableError(e.toString())) {
          rethrow;
        }
        
        // 等待后重试
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    
    throw lastError ?? Exception('未知错误');
  }
  
  bool _isRetryableError(String error) {
    return error.contains('connection abort') ||
           error.contains('timeout') ||
           error.contains('SocketException') ||
           error.contains('Connection closed');
  }
  
  Future<String?> _sendRequest(
    List<Message> history,
    String newPrompt,
    List<String>? attachedImages,
  ) async {
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
        // AI消息：不重复发送
        if (msg.imageUrl != null) {
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
    
    print('Endpoint: ${AppConfig.apiEndpoint}');
    print('Model: ${AppConfig.model}');
    print('Messages: ${messages.length}');
    
    final request = http.Request('POST', Uri.parse(AppConfig.apiEndpoint));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': AppConfig.model,
      'messages': messages,
    });
    
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request).timeout(
        Duration(seconds: 180),
      );
      
      final response = await http.Response.fromStream(streamedResponse).timeout(
        Duration(seconds: 180),
      );
      
      print('Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (data['choices'] == null || (data['choices'] as List).isEmpty) {
          throw Exception('API返回数据格式错误：无choices');
        }
        
        final content = data['choices'][0]['message']['content'];
        print('Content: $content');
        
        if (content == null) {
          throw Exception('API返回content为空');
        }
        
        final contentStr = content.toString();
        
        // 解析 ![image](URL) 格式
        final match = RegExp(r'!\[.*?\]\((https?://[^)]+)\)').firstMatch(contentStr);
        if (match != null) {
          return match.group(1);
        }
        
        // 尝试直接URL
        final urlMatch = RegExp(r'https?://\S+\.(png|jpg|jpeg|webp)').firstMatch(contentStr);
        if (urlMatch != null) {
          return urlMatch.group(0);
        }
        
        // 尝试base64
        if (contentStr.contains('data:image')) {
          return contentStr;
        }
        
        throw Exception('未找到图片URL');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['error']?['message'] ?? '请求失败 (${response.statusCode})');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('HTTP错误: ${e.message}');
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，API响应时间较长');
      }
      if (e.toString().contains('connection abort') || e.toString().contains('Connection closed')) {
        throw Exception('连接中断，请检查网络后重试');
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
