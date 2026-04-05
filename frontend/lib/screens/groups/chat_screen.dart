import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/common_widgets.dart';

class ChatScreen extends StatefulWidget {
  final GroupModel group;
  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _groupService = GroupService();
  final _chatService = ChatService();

  List<MessageModel> _messages = [];
  bool _isLoadingHistory = true;
  bool _isSending = false;
  bool _isTyping = false;
  String? _typingName;
  Timer? _typingTimer;
  int? _currentUserId;

  // Placeholder — in real app, get from auth provider
  static const int _myUserId = 1;

  @override
  void initState() {
    super.initState();
    _currentUserId = _myUserId;
    _loadHistory();
    _connectWebSocket();
  }

  Future<void> _loadHistory() async {
    final messages = await _groupService.getMessages(widget.group.id);
    if (mounted) setState(() { _messages = messages; _isLoadingHistory = false; });
    _scrollToBottom();
  }

  void _connectWebSocket() {
    _chatService.connect(widget.group.id);

    _chatService.messageStream.listen((data) {
      if (!mounted) return;
      if (data['_deleted'] == true) {
        setState(() {
          _messages = _messages.map((m) {
            if (m.id == data['message_id']) {
              return MessageModel(
                id: m.id, groupId: m.groupId, sender: m.sender,
                messageType: m.messageType, content: '[Message deleted]',
                isDeleted: true, createdAt: m.createdAt,
              );
            }
            return m;
          }).toList();
        });
      } else {
        setState(() => _messages.add(MessageModel.fromJson(data)));
        _scrollToBottom();
      }
    });

    _chatService.typingStream.listen((data) {
      if (!mounted || data['staff_id'] == _currentUserId) return;
      setState(() { _isTyping = true; _typingName = data['full_name']; });
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() { _isTyping = false; _typingName = null; });
      });
    });
  }

  void _scrollToBottom() {
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

  void _onTextChanged(String value) {
    if (value.isNotEmpty) _chatService.sendTyping();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    _messageController.clear();
    _chatService.sendMessage(content: text);
  }

  // ── NEW: Date separator helpers ────────────────────────────────────────────

  bool _showDateSeparator(int index) {
    if (index == 0) return true;
    final prev = DateTime.tryParse(_messages[index - 1].createdAt)?.toLocal();
    final curr = DateTime.tryParse(_messages[index].createdAt)?.toLocal();
    if (prev == null || curr == null) return false;
    return prev.year != curr.year ||
        prev.month != curr.month ||
        prev.day != curr.day;
  }

  String _dateLabel(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(dt.year, dt.month, dt.day);
    final diff  = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return DateFormat('EEEE').format(dt);
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Widget _buildDateSeparator(String createdAt) {
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _dateLabel(dt),
          style: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No messages yet',
                        subtitle: 'Be the first to say something!')
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (_isTyping && i == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          final msg = _messages[i];
                          final isMe = msg.sender?.id == _currentUserId;
                          final showAvatar = !isMe &&
                              (i == 0 || _messages[i - 1].sender?.id != msg.sender?.id);

                          // ── NEW: show date separator when day changes ──
                          final showDate = _showDateSeparator(i);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDate)
                                _buildDateSeparator(msg.createdAt),
                              _MessageBubble(
                                message: msg,
                                isMe: isMe,
                                showSenderInfo: showAvatar,
                                onLongPress: isMe && !msg.isDeleted
                                    ? () => _confirmDelete(msg)
                                    : null,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ─── Input Bar ─────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTextChanged,
                      maxLines: 4,
                      minLines: 1,
                      style: GoogleFonts.sora(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.sora(fontSize: 14, color: AppColors.textHint),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(widget.group.initials,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.group.name,
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
              Text('${widget.group.memberCount} members',
                style: GoogleFonts.sora(fontSize: 11, color: AppColors.textSecondary)),
            ],
          )),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${_typingName ?? 'Someone'} is typing',
              style: GoogleFonts.sora(fontSize: 12, color: AppColors.textSecondary,
                fontStyle: FontStyle.italic)),
            const SizedBox(width: 6),
            const SizedBox(width: 18, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight)),
          ]),
        ),
      ]),
    );
  }

  void _confirmDelete(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Delete Message', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('This message will be deleted for everyone.',
            style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _groupService.deleteMessage(widget.group.id, msg.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'))),
          ]),
        ]),
      ),
    );
  }
}

// ─── Message Bubble (unchanged) ───────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSenderInfo;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSenderInfo,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showSenderInfo)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: StaffAvatar(
                avatarUrl: message.sender?.avatarUrl,
                initials: message.sender?.initials ?? '??',
                size: 32,
              ),
            )
          else if (!isMe)
            const SizedBox(width: 40),

          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && showSenderInfo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 4),
                      child: Text(
                        message.sender?.fullName ?? '',
                        style: GoogleFonts.sora(fontSize: 11,
                          fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),

                  Container(
                    padding: message.messageType == 'meeting_invite'
                        ? const EdgeInsets.all(14)
                        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      gradient: isMe ? AppColors.primaryGradient : null,
                      color: isMe ? null : AppColors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      border: isMe ? null : Border.all(color: AppColors.border),
                    ),
                    child: message.messageType == 'meeting_invite'
                        ? _buildMeetingInvite(context)
                        : Text(
                            message.isDeleted ? 'Message deleted' : (message.content ?? ''),
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              color: message.isDeleted
                                  ? (isMe ? Colors.white60 : AppColors.textHint)
                                  : (isMe ? Colors.white : AppColors.textPrimary),
                              fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(time,
                      style: GoogleFonts.sora(fontSize: 10, color: AppColors.textHint)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingInvite(BuildContext context) {
    final lines = (message.content ?? '').split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isMe ? Colors.white : AppColors.primary).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.videocam_rounded,
              color: isMe ? Colors.white : AppColors.primary, size: 16)),
          const SizedBox(width: 8),
          Text('Meeting Invite', style: GoogleFonts.sora(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: isMe ? Colors.white : AppColors.primary)),
        ]),
        const SizedBox(height: 10),
        ...lines.map((line) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(line, style: GoogleFonts.sora(
            fontSize: 13, color: isMe ? Colors.white : AppColors.textPrimary)),
        )),
      ],
    );
  }

  String _formatTime(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }
}