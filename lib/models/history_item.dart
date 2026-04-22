import 'dart:convert';

class HistoryItem {
  final String id;
  final String prompt;
  final String imageUrl;
  final String type; // 'generate', 'edit', 'blend'
  final DateTime createdAt;
  final List<String>? sourceImageUrls;
  
  HistoryItem({
    required this.id,
    required this.prompt,
    required this.imageUrl,
    required this.type,
    required this.createdAt,
    this.sourceImageUrls,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'imageUrl': imageUrl,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'sourceImageUrls': sourceImageUrls,
    };
  }
  
  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      prompt: json['prompt'],
      imageUrl: json['imageUrl'],
      type: json['type'],
      createdAt: DateTime.parse(json['createdAt']),
      sourceImageUrls: json['sourceImageUrls'] != null 
        ? List<String>.from(json['sourceImageUrls'])
        : null,
    );
  }
  
  static String encodeList(List<HistoryItem> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
  
  static List<HistoryItem> decodeList(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => HistoryItem.fromJson(e)).toList();
  }
}
