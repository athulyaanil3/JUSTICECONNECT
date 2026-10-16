import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  String _groqApiKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  
  final List<String> _suggestedPrompts = [
    'Explain "Habeas Corpus"',
    'Documents needed for property registration?',
    'How to file a consumer complaint?',
    'What are my workplace rights?',
  ];

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('groq_api_key');
    if (mounted) {
      setState(() {
        _groqApiKey = (savedKey != null && savedKey.isNotEmpty)
            ? savedKey
            : const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
      });
    }
  }

  Future<void> _saveApiKey(String newKey) async {
    final trimmed = newKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', trimmed);
    if (mounted) {
      setState(() {
        _groqApiKey = trimmed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Groq API Key saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showApiKeyDialog() {
    final keyController = TextEditingController(text: _groqApiKey);
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.vpn_key, color: Color(0xFF0D256C)),
              SizedBox(width: 8),
              Text('Groq API Key'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your Groq Cloud API key to power the AI Legal Assistant.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'API Key (starts with gsk_...)',
                  hintText: 'gsk_...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setDialogState(() => obscure = !obscure);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tip: Get a free key at console.groq.com/keys',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D256C),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _saveApiKey(keyController.text);
              },
              child: const Text('Save Key'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'isMe': true, 'text': text});
      _isLoading = true;
    });
    
    _controller.clear();
    _scrollToBottom();

    if (_groqApiKey.trim().isEmpty) {
      setState(() {
        _messages.add({
          'isMe': false,
          'text': '⚠️ Groq API Key is not configured.\n\nPlease tap the Key icon in the top right to enter your Groq API key (starts with "gsk_..."). You can get a free key from console.groq.com/keys.',
          'requiresKey': true,
        });
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      final systemPrompt =
          'You are a friendly Legal Assistant for JusticeConnect in India. Your job is to give EXTREMELY SIMPLE, easy-to-understand answers to regular citizens. '
          'When a user asks a question, always structure your answer strictly as follows:\n'
          '1. Likely Law: State the relevant legal section (e.g., BNS, IPC, CrPC, Consumer Protection Act) in one simple sentence.\n'
          '2. Required Documents: Provide a simple bulleted list of 3-4 documents they need.\n'
          '3. Next Step: One simple sentence on what to do next.\n'
          'DO NOT use complex legal jargon. DO NOT write long paragraphs. Keep it very short, clear, and to the point.';

      final messagesPayload = [
        {'role': 'system', 'content': systemPrompt},
        ..._messages
            .where((m) => m['requiresKey'] != true)
            .skip(1)
            .map((m) => {
                  'role': m['isMe'] ? 'user' : 'assistant',
                  'content': m['text'],
                }),
      ];

      // Try primary model: openai/gpt-oss-20b, fallback to openai/gpt-oss-120b / qwen/qwen3.8-27b
      http.Response response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${_groqApiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-20b',
          'messages': messagesPayload,
          'temperature': 0.7,
        }),
      );

      // Fallback if model not available or rate limited
      if (response.statusCode != 200 && response.statusCode != 401) {
        response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${_groqApiKey.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'openai/gpt-oss-120b',
            'messages': messagesPayload,
            'temperature': 0.7,
          }),
        );
      }

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

        if (response.statusCode == 401) {
          errorMsg = 'Invalid Groq API Key. Please verify your key at console.groq.com/keys and tap the Key icon above to update it.';
        }

        setState(() {
          _messages.add({
            'isMe': false,
            'text': 'API Error: $errorMsg',
            'requiresKey': response.statusCode == 401,
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'isMe': false, 'text': 'Connection error: $e. Please check your internet connection.'});
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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'AI Legal Assistant',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(
              Icons.vpn_key_outlined,
              color: _groqApiKey.isEmpty ? Colors.orange : const Color(0xFF0D256C),
            ),
            tooltip: 'Configure Groq API Key',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_groqApiKey.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.brown, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Groq API key not set. Tap to configure.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.brown.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _showApiKeyDialog,
                    child: const Text('Configure', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
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
                  requiresKey: msg['requiresKey'] == true,
                );
              },
            ),
          ),
          _buildChatInput(context),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, {required bool isMe, required String message, bool requiresKey = false}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : (requiresKey ? Colors.amber.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: requiresKey ? Colors.amber.shade400 : Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.inter(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (requiresKey) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.vpn_key, size: 16),
                label: const Text('Enter Groq API Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D256C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _showApiKeyDialog,
              ),
            ],
          ],
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
