// lib/widgets/engagement/live_chat_overlay.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/user_session.dart';

class ChatMessage {
  final String id;
  final String username;
  final String text;
  final bool isMe;
  final Color color;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.username,
    required this.text,
    required this.isMe,
    required this.color,
    required this.timestamp,
  });
}

class LiveChatOverlay extends StatefulWidget {
  const LiveChatOverlay({super.key});

  @override
  State<LiveChatOverlay> createState() => _LiveChatOverlayState();
}

class _LiveChatOverlayState extends State<LiveChatOverlay> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  
  Timer? _fakeChatTimer;
  Timer? _cleanupTimer;
  final Random _random = Random();

  final List<String> _fakeUsernames = [
    'Rahul99', 'Priya_S', 'GamerBoy', 'Vikas007', 'Karan_King', 
    'Sneha_Win', 'AmitB', 'Ravi_Don', 'Player101', 'Lucky_Charm'
  ];

  final List<String> _fakeMessages = [
    'Let\'s goooo! 🔥',
    'Andar is definitely winning this round',
    'M********** I lost my 500 rs',
    'Bahar always comes after 2 Andars',
    'F*** this game rigged!',
    'Hahaha nice win',
    'Who is from Mumbai here?',
    'I bet 1000 on Bahar, pray for me 🤞',
    'Shit man... B*******d 🤬',
    'Wow, joker card again?',
    'Ez money 🤑',
    'My luck is so bad today :(',
    'WTF M********** why always Bahar!',
  ];

  final List<Color> _userColors = [
    const Color(0xFFEF4444), // Bahar Red
    const Color(0xFF3B82F6), // Andar Blue
    const Color(0xFFFFD700), // Gold
    const Color(0xFF10B981), // Green
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF97316), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _startFakeChats();
    _startCleanupTimer();

    // Auto-collapse if user taps outside and keyboard closes
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _isTyping = false);
      }
    });
  }

  @override
  void dispose() {
    _fakeChatTimer?.cancel();
    _cleanupTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startFakeChats() {
    final nextDelay = Duration(seconds: _random.nextInt(5) + 2); 
    _fakeChatTimer = Timer(nextDelay, () {
      if (!mounted) return;
      _addMessage(
        username: _fakeUsernames[_random.nextInt(_fakeUsernames.length)],
        text: _fakeMessages[_random.nextInt(_fakeMessages.length)],
        isMe: false,
        color: _userColors[_random.nextInt(_userColors.length)],
      );
      _startFakeChats();
    });
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      bool removed = false;
      _messages.removeWhere((m) {
        if (now.difference(m.timestamp).inSeconds > 6) { // Disappear after 6s
          removed = true;
          return true;
        }
        return false;
      });
      if (removed) setState(() {});
    });
  }

  void _addMessage({
    required String username,
    required String text,
    required bool isMe,
    Color? color,
  }) {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString() + _random.nextInt(1000).toString(),
          username: username,
          text: text,
          isMe: isMe,
          color: color ?? Colors.white,
          timestamp: DateTime.now(),
        ),
      );
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) {
      setState(() => _isTyping = false);
      _focusNode.unfocus();
      return;
    }

    final myName = UserSession.instance.name ?? 'You';
    _addMessage(
      username: myName,
      text: text,
      isMe: true,
      color: const Color(0xFF4ADE80), 
    );
    
    _msgController.clear();
    setState(() => _isTyping = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // Allows the popup to slide in from outside
      children: [
        // ── Messages Feed (LEFT ALIGNED) ──
        Positioned(
          left: 0,
          bottom: 0, 
          top: 0,
          width: 240, 
          child: IgnorePointer( 
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white.withOpacity(1.0)],
                  stops: const [0.0, 0.3],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Align( 
                alignment: Alignment.bottomLeft,
                // Animates the text up slightly so the popup doesn't cover it
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: _isTyping ? 55 : 0),
                  child: ListView.builder(
                    shrinkWrap: true, 
                    controller: _scrollController,
                    padding: EdgeInsets.zero, 
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageItem(msg);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // ── Chat Button (RIGHT ALIGNED, FADES OUT WHEN TYPING) ──
        Positioned(
          right: 0,
          bottom: 0, 
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isTyping ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: _isTyping,
              child: _buildCollapsedButton(),
            ),
          ),
        ),

        // ── SMS Input Popup (SLIDES BOTTOM TO TOP) ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack, // Gives it a satisfying springy popup effect
          left: 0,
          right: 0, // Stretches across the width you allocated in Game Screen
          // Slides up to 0 when typing, slides down to -80 (hidden) when closed
          bottom: _isTyping ? 0 : -80, 
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _isTyping ? 1.0 : 0.0,
            child: _buildExpandedInput(),
          ),
        ),
      ],
    );
  }

  // Modern transparent text styling
  Widget _buildMessageItem(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${msg.username}: ',
              style: TextStyle(
                color: msg.color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1))
                ],
              ),
            ),
            TextSpan(
              text: msg.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1))
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Full text field popup (Slides up from bottom)
  Widget _buildExpandedInput() {
    return Container(
      height: 48, // Nice comfortable height for the popup
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75), // Transparent dark background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _msgController,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFFFFD700), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  // Small pill button when not typing
  Widget _buildCollapsedButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _isTyping = true);
        _focusNode.requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Colors.white.withOpacity(0.8), size: 16),
            const SizedBox(width: 8),
            Text(
              'Chat',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}