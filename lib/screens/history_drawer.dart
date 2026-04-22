import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';

class HistoryDrawer extends StatelessWidget {
  final List<ChatSession> sessions;
  final String? currentSessionId;
  final Function(ChatSession) onSelect;
  final Function(ChatSession) onDelete;
  final VoidCallback onNewChat;
  
  const HistoryDrawer({
    super.key,
    required this.sessions,
    this.currentSessionId,
    required this.onSelect,
    required this.onDelete,
    required this.onNewChat,
  });
  
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    '历史对话',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF667EEA)),
                    onPressed: onNewChat,
                    tooltip: '新建对话',
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            Expanded(
              child: sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          '暂无历史对话',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isSelected = session.id == currentSessionId;
                      final lastMessage = session.messages.isNotEmpty
                        ? session.messages.last
                        : null;
                      
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF667EEA).withOpacity(0.2),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                            ? const Color(0xFF667EEA)
                            : Colors.grey[700],
                          child: const Icon(Icons.chat, size: 20, color: Colors.white),
                        ),
                        title: Text(
                          session.title,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF667EEA) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: lastMessage != null
                          ? Row(
                              children: [
                                if (lastMessage.imageUrl != null)
                                  const Icon(Icons.image, size: 12, color: Colors.grey),
                                if (lastMessage.attachedImages != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      '${lastMessage.attachedImages!.length}图',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    lastMessage.text ?? (lastMessage.imageUrl != null ? '[图片]' : ''),
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => onDelete(session),
                        ),
                        onTap: () {
                          onSelect(session);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
