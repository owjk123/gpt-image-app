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
    
    print('=== API Request ===');
    print('Messages: ${messages.length}');
    
    // 使用普通POST请求而不是流式
    try {
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
      ).timeout(Duration(seconds: 180));
      
      print('=== API Response ===');
      print('Status: ${response.statusCode}');
      
      final bodyStr = utf8.decode(response.bodyBytes);
      print('Body length: ${bodyStr.length}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(bodyStr);
        
        if (data['choices'] == null) {
          print('No choices in response');
          print('Full response: $bodyStr');
          throw Exception('API返回格式错误');
        }
        
        final choices = data['choices'] as List;
        if (choices.isEmpty) {
          print('Empty choices');
          throw Exception('API返回空结果');
        }
        
        final content = choices[0]['message']['content'];
        print('Content: $content');
        
        if (content == null) {
          print('Content is null');
          throw Exception('API返回空内容');
        }
        
        final contentStr = content.toString();
        
        // 解析 ![image](URL) 格式
        final match = RegExp(r'!\[.*?\]\((https?://[^)]+)\)').firstMatch(contentStr);
        if (match != null) {
          final url = match.group(1)!;
          print('Found image URL: $url');
          return url;
        }
        
        // 尝试直接URL
        final urlMatch = RegExp(r'https?://[^\s)"\'\]]+').firstMatch(contentStr);
        if (urlMatch != null) {
          final url = urlMatch.group(0)!;
          print('Found direct URL: $url');
          return url;
        }
        
        // base64
        if (contentStr.contains('data:image')) {
          print('Found base64 image');
          return contentStr;
        }
        
        print('No image found in: $contentStr');
        throw Exception('未找到图片');
      } else {
        final error = jsonDecode(bodyStr);
        throw Exception(error['error']?['message'] ?? '请求失败');
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      throw Exception('网络错误: ${e.message}');
    } on HttpException catch (e) {
      print('HttpException: $e');
      throw Exception('HTTP错误: ${e.message}');
    } catch (e) {
      print('Exception: $e');
      final errStr = e.toString();
      if (errStr.contains('timeout') || errStr.contains('TimeoutException')) {
        throw Exception('请求超时');
      }
      if (errStr.contains('connection abort') || 
          errStr.contains('Connection closed') ||
          errStr.contains('SocketException')) {
        throw Exception('网络连接中断');
      }
      rethrow;
    }
  }
}
