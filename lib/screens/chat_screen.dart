import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/input_bar.dart';
import '../widgets/full_image_viewer.dart';
import 'history_drawer.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Uuid _uuid = const Uuid();
  
  ChatSession? _currentSession;
  List<ChatSession> _sessions = [];
  bool _isLoading = false;
  String _apiKey = '';
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key') ?? '';
    
    final sessionsJson = prefs.getString('chat_sessions');
    if (sessionsJson != null) {
      final List<dynamic> list = jsonDecode(sessionsJson);
      _sessions = list.map((e) => ChatSession.fromJson(e)).toList();
    }
    
    if (_sessions.isEmpty) {
      _createNewSession();
    } else {
      _currentSession = _sessions.first;
    }
    
    setState(() {});
  }
  
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'chat_sessions',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }
  
  void _createNewSession() {
    final newSession = ChatSession(
      id: _uuid.v4(),
      title: '新对话',
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _sessions.insert(0, newSession);
      _currentSession = newSession;
    });
    _saveSessions();
  }
  
  Future<void> _sendMessage(String text, List<String> images) async {
    if (_apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 API Key')),
      );
      return;
    }
    
    if (_currentSession == null) return;
    
    // 添加用户消息
    final userMessage = Message(
      id: _uuid.v4(),
      isUser: true,
      text: text.isNotEmpty ? text : null,
      attachedImages: images.isNotEmpty ? images : null,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _currentSession!.messages.add(userMessage);
      _isLoading = true;
    });
    
    // 更新标题
    if (_currentSession!.title == '新对话' && text.isNotEmpty) {
      _currentSession!.title = text.length > 20 ? '${text.substring(0, 20)}...' : text;
    }
    
    _scrollToBottom();
    await _saveSessions();
    
    // 调用API
    try {
      final apiService = ApiService(_apiKey);
      final imageUrl = await apiService.sendMessage(
        history: _currentSession!.messages
            .where((m) => m.id != userMessage.id)
            .toList(),
        newPrompt: text,
        attachedImages: images,
      );
      
      // 添加AI回复
      final aiMessage = Message(
        id: _uuid.v4(),
        isUser: false,
        text: imageUrl != null ? null : '生成失败，请重试',
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _currentSession!.messages.add(aiMessage);
        _currentSession!.updatedAt = DateTime.now();
        _isLoading = false;
      });
      
      await _saveSessions();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    }
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _selectSession(ChatSession session) {
    setState(() {
      _currentSession = session;
    });
  }
  
  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('删除对话', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除"${session.title}"吗？',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
        if (_currentSession?.id == session.id) {
          if (_sessions.isEmpty) {
            _createNewSession();
          } else {
            _currentSession = _sessions.first;
          }
        }
      });
      await _saveSessions();
    }
  }
  
  Future<void> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;
      
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('无法访问存储目录');
      }
      
      final fileName = 'gpt_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片已保存到: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
  
  void _openImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageViewer(imageUrl: imageUrl),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: GestureDetector(
          onTap: _createNewSession,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentSession?.title ?? 'AI 生图',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit, color: Colors.grey, size: 16),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      drawer: HistoryDrawer(
        sessions: _sessions,
        currentSessionId: _currentSession?.id,
        onSelect: _selectSession,
        onDelete: _deleteSession,
        onNewChat: () {
          Navigator.pop(context);
          _createNewSession();
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentSession == null || _currentSession!.messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _currentSession!.messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoading && index == _currentSession!.messages.length) {
                      return const TypingIndicator();
                    }
                    
                    final message = _currentSession!.messages[index];
                    return Column(
                      children: [
                        MessageBubble(
                          message: message,
                          onImageTap: message.imageUrl != null
                            ? () => _openImage(message.imageUrl!)
                            : null,
                        ),
                        if (message.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 48),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _downloadImage(message.imageUrl!),
                                  icon: const Icon(Icons.download, size: 18),
                                  label: const Text('保存'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
          ),
          InputBar(
            onSend: _sendMessage,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'AI 图片生成器',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '输入描述，让AI为你创作图片\n支持添加参考图进行编辑和融合',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildTipCard('🎨 文生图', '描述你想要的图片'),
          const SizedBox(height: 12),
          _buildTipCard('✏️ 图片编辑', '上传图片 + 编辑指令'),
          const SizedBox(height: 12),
          _buildTipCard('🔄 多图融合', '上传多张图片 + 融合描述'),
        ],
      ),
    );
  }
  
  Widget _buildTipCard(String title, String desc) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          Text(desc, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }
}
