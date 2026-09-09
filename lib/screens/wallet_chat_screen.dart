import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/chat_message_model.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
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
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.05)),
              ),
              child: Text(
                msg.message,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                maxLines: 4,
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
                  color: const Color(0xFF60A5FA).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.pencil,
                    color: Color(0xFF60A5FA), size: 20),
              ),
              title: const Text('Edit Pesan',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.3)),
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
                  child: const Icon(CupertinoIcons.trash,
                      color: AppColors.expense, size: 20),
                ),
                title: const Text('Hapus Pesan',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: AppColors.expense)),
                subtitle: Text(
                  'Sisa waktu: ${15 - DateTime.now().difference(msg.timestamp).inMinutes} menit',
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
                  child: Icon(CupertinoIcons.timer,
                      color: AppColors.textHint.withOpacity(0.5), size: 20),
                ),
                title: Text('Hapus Pesan',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: AppColors.textHint.withOpacity(0.5))),
                subtitle: const Text('Batas waktu 15 menit sudah lewat',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmUnsend(ChatMessage msg) async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Hapus Pesan?',
      message:
          'Pesan ini akan dihapus untuk semua orang. Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Ya, Hapus',
      isDangerous: true,
    );

    if (confirm == true) {
      _firestoreService.deleteMessage(
        walletId: widget.walletId,
        messageId: msg.id,
      );
    }
  }

  // Track the most recent message ID to avoid redundant read-receipt writes
  String? _lastSeenMsgId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF4F4F7),
      appBar: AppBar(
        backgroundColor: navBgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leadingWidth: 40,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(CupertinoIcons.chevron_left,
                size: 22, color: isDark ? Colors.white : AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(CupertinoIcons.person_2_fill,
                  color: Color(0xFF60A5FA), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.walletName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Chat Grup',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: dividerColor,
          ),
        ),
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                // If new messages found, update read-receipt
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final latestMsg = snapshot.data!.first;
                  if (latestMsg.id != _lastSeenMsgId) {
                    _lastSeenMsgId = latestMsg.id;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _firestoreService.markChatAsRead(
                          widget.walletId, _currentUser.uid,
                          until: latestMsg.timestamp);
                    });
                  }
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CupertinoActivityIndicator(radius: 12),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.chat_bubble_2_fill,
                              size: 42,
                              color: Color(0xFF60A5FA)),
                        ),
                        const SizedBox(height: 16),
                        Text('Belum ada pesan',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        Text(
                            'Mulai obrolan dengan anggota\ndompet kolaborasi ini!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isDark ? Colors.white54 : AppColors.textHint,
                                fontSize: 13,
                                height: 1.3)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderUid == _currentUser.uid;

                    // Show avatar logic when grouping consecutive messages from same user
                    final showAvatar = index == 0 ||
                        messages[index - 1].senderUid != msg.senderUid;

                    // Date header logic (since reverse: true, index + 1 is the older message)
                    bool showDateHeader = false;
                    if (index == messages.length - 1) {
                      showDateHeader = true;
                    } else {
                      final currentMsgDate = msg.timestamp;
                      final olderMsgDate = messages[index + 1].timestamp;
                      if (!_isSameDay(currentMsgDate, olderMsgDate)) {
                        showDateHeader = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateHeader) _buildDateHeader(msg.timestamp),
                        GestureDetector(
                          onLongPress: () => _showMessageActions(msg),
                          child: _buildMessageBubble(msg, isMe, showAvatar, isDark),
                        ),
                      ],
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
              color: isDark
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.08),
              child: Row(
                children: [
                  Container(
                      width: 3.5,
                      height: 28,
                      decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mengedit pesan',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange)),
                        Text('Tekan silang untuk membatalkan',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : AppColors.textHint)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CupertinoIcons.xmark,
                          size: 14,
                          color: isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _formatDateHeader(date),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      ChatMessage msg, bool isMe, bool showAvatar, bool isDark) {
    final avatarColor = _getAvatarColor(msg.senderName);
    final senderNameColor = _getSenderNameColor(msg.senderName, isDark);

    return Padding(
      padding: EdgeInsets.only(
        bottom: showAvatar ? 8 : 3,
        left: isMe ? 52 : 0,
        right: isMe ? 0 : 52,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (only for others)
          if (!isMe && showAvatar)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: avatarColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  msg.senderName.isNotEmpty
                      ? msg.senderName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            )
          else if (!isMe)
            const SizedBox(width: 38),

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: senderNameColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: msg.isDeleted
                        ? null
                        : (isMe
                            ? const LinearGradient(
                                colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null),
                    color: msg.isDeleted
                        ? (isMe
                            ? (isDark ? Colors.grey[850] : Colors.grey[300])
                            : (isDark ? Colors.grey[900] : Colors.grey[200]))
                        : (isMe
                            ? null
                            : (isDark
                                ? const Color(0xFF242428)
                                : const Color(0xFFE9E9EB))),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isMe ? 18 : (showAvatar ? 4 : 18)),
                      bottomRight:
                          Radius.circular(isMe ? (showAvatar ? 4 : 18) : 18),
                    ),
                    border: (!isMe && isDark && !msg.isDeleted)
                        ? Border.all(
                            color: Colors.white.withOpacity(0.08), width: 0.5)
                        : null,
                    boxShadow: [
                      if (isMe && !msg.isDeleted)
                        BoxShadow(
                          color: const Color(0xFF60A5FA).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      else if (!isMe && !isDark)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
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
                            Icon(CupertinoIcons.slash_circle,
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
                            fontSize: 14.5,
                            color: isMe
                                ? Colors.white
                                : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                            height: 1.35,
                            letterSpacing: -0.2,
                          ),
                        ),
                      const SizedBox(height: 3),
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
                                    ? Colors.white.withOpacity(0.6)
                                    : (isDark
                                        ? Colors.white38
                                        : AppColors.textHint),
                              ),
                            ),
                          Text(
                            DateFormat('HH:mm').format(msg.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : (isDark
                                      ? Colors.white38
                                      : AppColors.textHint),
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

  Widget _buildInputBar(bool isDark) {
    final barBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(color: borderCol, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.transparent),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: _isEditing ? 'Ubah pesan...' : 'Masukkan pesan...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : AppColors.textHint,
                      fontSize: 14.5,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: _isEditing
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _isEditing ? Colors.orange : null,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isEditing ? Colors.orange : const Color(0xFF60A5FA))
                        .withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isEditing
                    ? CupertinoIcons.check_mark
                    : CupertinoIcons.arrow_up,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF60A5FA), // Pastel Blue
      Color(0xFF80EF80), // Pastel Green
      Color(0xFFFFC067), // Pastel Orange
      Color(0xFFC084FC), // Pastel Purple
      Color(0xFFFF746C), // Pastel Red
      Color(0xFF38BDF8), // Pastel Sky
      Color(0xFFFFEE8C), // Pastel Yellow
      Color(0xFFF472B6), // Pastel Pink
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  Color _getSenderNameColor(String name, bool isDark) {
    const lightColors = [
      Color(0xFF0056D6),
      Color(0xFF1B8A3E),
      Color(0xFFC76A00),
      Color(0xFF8E24AA),
      Color(0xFFD32F2F),
      Color(0xFF00838F),
    ];
    const darkColors = [
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
      Color(0xFFBA68C8),
      Color(0xFFE57373),
      Color(0xFF4DD0E1),
    ];
    final colors = isDark ? darkColors : lightColors;
    return colors[name.hashCode.abs() % colors.length];
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Hari ini';
    } else if (msgDate == yesterday) {
      return 'Kemarin';
    } else if (date.year == now.year) {
      return DateFormat('d MMMM').format(date);
    } else {
      return DateFormat('d MMMM yyyy').format(date);
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}

