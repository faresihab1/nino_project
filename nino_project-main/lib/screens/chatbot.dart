import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nino/widgets/background.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key, required this.childId});

  final int? childId;

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  // ✅ Your NGROK base URL (changes when ngrok restarts)
  final String _baseUrl =
      "https://sina-nonastronomical-jule.ngrok-free.dev";

  // ✅ Chat endpoint path on the FastAPI server
  static const String _chatPath = "/chat";

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ Build messages payload to store in Supabase as text[]
  List<String> _buildMessagesPayload() {
    return _messages
        .where((m) => !(m.isUser == false && m.text == "Typing..."))
        .map((m) => (m.isUser ? "user: " : "bot: ") + m.text)
        .toList();
  }

  // ✅ Save to Supabase table chatbot(child_id, messages)
  Future<void> _saveChatToSupabase() async {
    if (widget.childId == null) return;

    final payload = _buildMessagesPayload();
    if (payload.isEmpty) return;

    await _supabase.from("chatbot").insert({
      "child_id": widget.childId,
      "messages": payload, // text[]
    });
  }

  // ✅ Confirm exit and ask to save
  Future<bool> _confirmExitAndMaybeSave() async {
    if (_messages.isEmpty) return true;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Save chat?"),
        content: const Text("Do you want to save this chat to history?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      try {
        await _saveChatToSupabase();
      } catch (_) {
        // even if save fails, allow exit
      }
    }

    return true;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(const _ChatMessage(text: "Typing...", isUser: false));
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl$_chatPath"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "session_id": "default",
          "text": text, // ✅ backend expects "text"
        }),
      );

      String botReply = "Sorry, something went wrong.";

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        botReply = (data["reply"] ?? botReply).toString();
      } else {
        // Show backend detail (e.g., 404/422)
        try {
          final data = jsonDecode(response.body);
          botReply = (data["detail"] ?? response.body).toString();
        } catch (_) {
          botReply = "HTTP ${response.statusCode}: ${response.body}";
        }
      }

      setState(() {
        // remove Typing...
        _messages.removeLast();
        _messages.add(_ChatMessage(text: botReply, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          const _ChatMessage(
            text: "Unable to connect to server. Please try again.",
            isUser: false,
          ),
        );
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExitAndMaybeSave,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canExit = await _confirmExitAndMaybeSave();
              if (canExit && mounted) Navigator.of(context).pop();
            },
          ),
          title: const Text("Chatbot"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: const Color(0xFF0B3D2E),

          // ✅ History button
          actions: [
            IconButton(
              tooltip: 'History',
              icon: const Icon(Icons.history),
              onPressed: () {
                if (widget.childId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a child first.')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatHistoryPage(childId: widget.childId!),
                  ),
                );
              },
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            const Background(),
            SafeArea(
              child: Column(
                children: [
                  // top info box
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: Color(0xFF00916E)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Chatbot ready.',
                              style: TextStyle(
                                color: Color(0xFF0B3D2E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // chat messages area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: _messages.isEmpty
                            ? const _EmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.zero,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  return Align(
                                    alignment: msg.isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.78,
                                      ),
                                      decoration: BoxDecoration(
                                        color: msg.isUser
                                            ? const Color(0xFF00916E)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(16).copyWith(
                                          bottomRight: msg.isUser
                                              ? const Radius.circular(4)
                                              : const Radius.circular(16),
                                          bottomLeft: msg.isUser
                                              ? const Radius.circular(16)
                                              : const Radius.circular(4),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        msg.text,
                                        style: TextStyle(
                                          color: msg.isUser
                                              ? Colors.white
                                              : const Color(0xFF0B3D2E),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),

                  // input area
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: "Type a message...",
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.9),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.black.withOpacity(0.06),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF00916E),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                height: 46,
                                width: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00916E),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00916E)
                                          .withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Color(0xFF00916E),
          ),
          SizedBox(height: 12),
          Text(
            "Start a conversation",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0B3D2E),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}

// =======================
// ✅ HISTORY PAGES (READ ONLY)
// =======================

class ChatHistoryPage extends StatelessWidget {
  ChatHistoryPage({super.key, required this.childId});

  final int childId;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _loadChats() async {
    final res = await _supabase
        .from('chatbot')
        .select('chat_id, child_id, messages')
        .eq('child_id', childId)
        .order('chat_id', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load history: ${snapshot.error}'),
            );
          }

          final chats = snapshot.data ?? const [];
          if (chats.isEmpty) {
            return const Center(child: Text('No saved chats for this child yet.'));
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = chats[index];
              final chatId = row['chat_id'];
              final messages = (row['messages'] as List?)?.cast<String>() ?? <String>[];

              final title = 'Chat #$chatId';
              final preview = messages.isNotEmpty ? messages.first : '(empty)';

              return ListTile(
                title: Text(title),
                subtitle: Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatHistoryDetailPage(
                        chatId: (chatId is int) ? chatId : int.tryParse('$chatId') ?? 0,
                        childId: childId,
                        messages: messages,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ChatHistoryDetailPage extends StatelessWidget {
  const ChatHistoryDetailPage({
    super.key,
    required this.chatId,
    required this.childId,
    required this.messages,
  });

  final int chatId;
  final int childId;
  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat #$chatId'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final line = messages[index];
          final isUser = line.toLowerCase().startsWith('user:');

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF00916E) : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                line,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF0B3D2E),
                  height: 1.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}