import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class AIAssistantTab extends StatefulWidget {
  const AIAssistantTab({Key? key}) : super(key: key);

  @override
  _AIAssistantTabState createState() => _AIAssistantTabState();
}

class _AIAssistantTabState extends State<AIAssistantTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'isMe': false,
      'text': 'Hello! I am your AI Legal Assistant. If you are unsure which legal section your case falls under, or what documents you need, just describe your issue here and I will help you.'
    }
  ];

  final String _groqApiKey = '';
  
  final List<String> _suggestedPrompts = [
    'Explain "Habeas Corpus"',
    'Documents needed for property registration?',
    'How to file a consumer complaint?',
    'What are my workplace rights?',
  ];

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'isMe': true, 'text': text});
      _isLoading = true;
    });
    
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-20b',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a friendly Legal Assistant for JusticeConnect in India. Your job is to give EXTREMELY SIMPLE, easy-to-understand answers to regular citizens. '
                         'When a user asks a question, always structure your answer strictly as follows:\n'
                         '1. Likely Law: State the relevant legal section (e.g., IPC, CrPC) in one simple sentence.\n'
                         '2. Required Documents: Provide a simple bulleted list of 3-4 documents they need.\n'
                         '3. Next Step: One simple sentence on what to do next.\n'
                         'DO NOT use complex legal jargon. DO NOT write long paragraphs. Keep it very short, clear, and to the point.'
            },
            ..._messages.skip(1).map((m) => {
              'role': m['isMe'] ? 'user' : 'assistant',
              'content': m['text']
            }).toList(),
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['choices'][0]['message']['content'];
        setState(() {
          _messages.add({'isMe': false, 'text': aiMessage});
        });
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            errorMsg = errorData['error']['message'];
          } else {
            errorMsg = response.body;
          }
        } catch (_) {}

        setState(() {
          _messages.add({'isMe': false, 'text': 'API Error: $errorMsg'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'isMe': false, 'text': 'Connection error. Please check your internet connection.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'AI Legal Assistant',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  if (_isLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (_messages.length == 1) {
                    return _buildSuggestedPrompts(context);
                  } else {
                    return const SizedBox.shrink();
                  }
                }
                final msg = _messages[index];
                return _buildMessageBubble(
                  context,
                  isMe: msg['isMe'],
                  message: msg['text'],
                );
              },
            ),
          ),
          _buildChatInput(context),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, {required bool isMe, required String message}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          message,
          style: GoogleFonts.inter(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedPrompts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Suggested Questions',
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedPrompts.map((prompt) => _buildPromptChip(context, prompt)).toList(),
        ),
      ],
    );
  }

  Widget _buildPromptChip(BuildContext context, String text) {
    return ActionChip(
      label: Text(text),
      labelStyle: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).primaryColor),
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.05),
      side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.2)),
      onPressed: () {
        _sendMessage(text);
      },
    );
  }

  Widget _buildChatInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Type your legal question...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () {
                  _sendMessage(_controller.text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
