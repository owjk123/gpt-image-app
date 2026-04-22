import 'dart:convert';

class Message {
  final String id;
  final bool isUser;
  final String? text;
  final String? imageUrl;
  final List<String>? attachedImages;
  final DateTime timestamp;
  
  Message({
    required this.id,
    required this.isUser,
    this.text,
    this.imageUrl,
    this.attachedImages,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isUser': isUser,
      'text': text,
      'imageUrl': imageUrl,
      'attachedImages': attachedImages,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      isUser: json['isUser'],
      text: json['text'],
      imageUrl: json['imageUrl'],
      attachedImages: json['attachedImages'] != null
        ? List<String>.from(json['attachedImages'])
        : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
  
  Message copyWith({
    String? id,
    bool? isUser,
    String? text,
    String? imageUrl,
    List<String>? attachedImages,
    DateTime? timestamp,
  }) {
    return Message(
      id: id ?? this.id,
      isUser: isUser ?? this.isUser,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      attachedImages: attachedImages ?? this.attachedImages,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
  
  ChatSession copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
