import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/chat_message_model.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class WalletChatScreen extends StatefulWidget {
  final String walletId;
  final String walletName;

  const WalletChatScreen({
    super.key,
    required this.walletId,
    required this.walletName,
  });

  @override
  State<WalletChatScreen> createState() => _WalletChatScreenState();
}

class _WalletChatScreenState extends State<WalletChatScreen>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  // Edit mode state
  bool _isEditing = false;
  String? _editingMessageId;
  late Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messagesStream = _firestoreService.getMessagesStream(widget.walletId);
    // Mark as read when entering the chat
    _firestoreService.markChatAsRead(widget.walletId, _currentUser.uid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _firestoreService.markChatAsRead(widget.walletId, _currentUser.uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Mark as read when leaving the chat
    _firestoreService.markChatAsRead(widget.walletId, _currentUser.uid);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isEditing && _editingMessageId != null) {
      _firestoreService.editMessage(
        walletId: widget.walletId,
        messageId: _editingMessageId!,
        newMessage: text,
      );
      setState(() {
        _isEditing = false;
        _editingMessageId = null;
      });
    } else {
      _firestoreService.sendMessage(
        walletId: widget.walletId,
        senderUid: _currentUser.uid,
        senderName: _currentUser.displayName ?? 'Anonim',
        message: text,
      );
    }

    _messageController.clear();
  }

  void _startEditing(ChatMessage msg) {
    setState(() {
      _isEditing = true;
      _editingMessageId = msg.id;
      _messageController.text = msg.message;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  void _showMessageActions(ChatMessage msg) {
    final isMe = msg.senderUid == _currentUser.uid;
    if (!isMe || msg.isDeleted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 8,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textHint.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Preview bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                msg.message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Edit option
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                _startEditing(msg);
              },
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: AppColors.primary, size: 20),
              ),
              title: const Text('Edit Pesan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Ubah isi pesan ini',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            ),
            // Unsend option (only if within 5 minutes)
            if (msg.canUnsend)
              ListTile(
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmUnsend(msg);
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.expense, size: 20),
                ),
                title: const Text('Hapus Pesan',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.expense)),
                subtitle: Text(
                  'Bisa dihapus dalam ${5 - DateTime.now().difference(msg.timestamp).inMinutes} menit lagi',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ),
            if (!msg.canUnsend)
              ListTile(
                enabled: false,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timer_off_rounded,
                      color: AppColors.textHint.withOpacity(0.5), size: 20),
                ),
                title: Text('Hapus Pesan',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textHint.withOpacity(0.5))),
                subtitle: const Text('Batas waktu 5 menit sudah lewat',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmUnsend(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Pesan?'),
        content: const Text(
            'Pesan ini akan dihapus untuk semua orang. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _firestoreService.deleteMessage(
                walletId: widget.walletId,
                messageId: msg.id,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // Track the most recent message ID to avoid redundant read-receipt writes
  String? _lastSeenMsgId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.group_rounded,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.walletName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Chat Grup',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                // If new messages found, update our read-receipt
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final latestMsg = snapshot.data!.first;
                  if (latestMsg.id != _lastSeenMsgId) {
                    _lastSeenMsgId = latestMsg.id;
                    // Trigger markAsRead without blocking current build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _firestoreService.markChatAsRead(
                          widget.walletId, _currentUser.uid,
                          until: latestMsg.timestamp);
                    });
                  }
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: AppColors.primary.withOpacity(0.4)),
                        ),
                        const SizedBox(height: 20),
                        const Text('Belum ada pesan',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        const Text(
                            'Mulai obrolan dengan anggota\ndompet kolaborasi ini!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textHint, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderUid == _currentUser.uid;

                    final showAvatar = index == messages.length - 1 ||
                        messages[index + 1].senderUid != msg.senderUid;

                    return GestureDetector(
                      onLongPress: () => _showMessageActions(msg),
                      child: _buildMessageBubble(msg, isMe, showAvatar),
                    );
                  },
                );
              },
            ),
          ),

          // Edit mode banner
          if (_isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primary.withOpacity(0.06),
              child: Row(
                children: [
                  Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mengedit pesan',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                        Text('Tekan untuk membatalkan',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.textHint.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool showAvatar) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: showAvatar ? 12 : 4,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (only for others)
          if (!isMe && showAvatar)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _getAvatarColor(msg.senderName),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  msg.senderName.isNotEmpty
                      ? msg.senderName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            )
          else if (!isMe)
            const SizedBox(width: 40),

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getAvatarColor(msg.senderName)),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: msg.isDeleted
                        ? (isMe
                            ? AppColors.primary.withOpacity(0.3)
                            : Colors.white.withOpacity(0.6))
                        : (isMe ? AppColors.primary : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isMe ? 18 : (showAvatar ? 4 : 18)),
                      bottomRight:
                          Radius.circular(isMe ? (showAvatar ? 4 : 18) : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Message text (italic if deleted)
                      if (msg.isDeleted)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block_rounded,
                                size: 14,
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : AppColors.textHint),
                            const SizedBox(width: 6),
                            Text(
                              msg.message,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          msg.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe ? Colors.white : AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Timestamp + edited label
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg.isEdited && !msg.isDeleted)
                            Text(
                              'diedit  ',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: isMe
                                    ? Colors.white.withOpacity(0.5)
                                    : AppColors.textHint,
                              ),
                            ),
                          Text(
                            DateFormat('HH:mm').format(msg.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white.withOpacity(0.6)
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isEditing ? 'Edit pesan...' : 'Tulis pesan...',
                  hintStyle:
                      const TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isEditing ? AppColors.income : AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isEditing ? Icons.check_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFFF2D55),
      const Color(0xFF5856D6),
      const Color(0xFFAF52DE),
      const Color(0xFF00C7BE),
      const Color(0xFFFF6482),
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }
}
