import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nino/widgets/background.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  final String _apiUrl =
      "https://defervescent-jaylene-unspoiled.ngrok-free.dev/chat";

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": "1",
          "message": text,
        }),
      );

      String botReply = "Sorry, something went wrong.";

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        botReply = data["reply"] ?? botReply;
      }

      setState(() {
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
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF0B3D2E),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      Container(
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
                            Icon(Icons.info_outline,
                                color: Color(0xFF00916E)),
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
                      const SizedBox(height: 12),
                      Container(
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
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  return Align(
                                    alignment: msg.isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin:
                                          const EdgeInsets.symmetric(vertical: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context)
                                                .size
                                                .width *
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
                    ],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                ),
              ],
            ),
          ),
        ],
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
