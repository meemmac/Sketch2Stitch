// lib/screens/customer/messaging/chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/messaging_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String customerId; // Represents the logged in user's ID
  final String otherUserId;
  final String otherUserName;
  final UserRole otherUserRole;
  final UserRole currentUserRole; // 🆕 Added to identify sender
  final String? otherUserAvatar;
  final String? orderId;
  final Function(String)? onConversationRead;
  final bool? isBlocked;


  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.customerId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    required this.currentUserRole, // 🆕 Required now
    this.otherUserAvatar,
    this.orderId,
    this.onConversationRead,
    this.isBlocked,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  late Stream<List<Message>> _messageStream;
  late Stream<bool> _otherUserTypingStream;
  
  // Reply tracking
  String? _replyingToMessageId;
  String? _replyingToMessageText;
  String? _replyingToSender;
  
  String? _selectedMessageId;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  
  bool _isBlocked = false;
  bool _isUploading = false;
  bool _isSending = false; // 🆕 Added to show loading on button
  Timer? _typingTimer;


  // Overlay notification
  OverlayEntry? _notificationOverlay;

  @override
  void initState() {
    super.initState();
    
    _isBlocked = widget.isBlocked ?? false;
    _messageStream = _messagingService.getMessagesByConversationId(widget.conversationId);
    _otherUserTypingStream = _messagingService.streamTypingStatus(widget.conversationId, widget.otherUserId);
    
    _markAsRead();
    
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _typingAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingAnimationController.dispose();
    _removeNotificationOverlay();
    super.dispose();
  }

  void _markAsRead() {
    _messagingService.markMessagesRead(widget.conversationId, widget.customerId);
    if (widget.onConversationRead != null) {
      widget.onConversationRead!(widget.conversationId);
    }
  }

  // ─── Top Notification System ──────────────────────────────────────────

  void _showTopNotification(String message, {bool isError = false}) {
    _removeNotificationOverlay();
    
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? Colors.red[700] : const Color.fromARGB(255, 45, 141, 61), 
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.notifications_active,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeNotificationOverlay,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(entry);
    _notificationOverlay = entry;
    
    Future.delayed(const Duration(seconds: 2), () {
      _removeNotificationOverlay();
    });
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  // ─── Send Message ──────────────────────────────────────────────────

  void _onTyping(String text) {
    if (_typingTimer?.isActive ?? false) return;
    
    _messagingService.setTypingStatus(widget.conversationId, widget.customerId, true);
    
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _messagingService.setTypingStatus(widget.conversationId, widget.customerId, false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;


    debugPrint('🚀 [SEND] Button pressed. Text: $text');


    if (_isBlocked) {
      _showTopNotification('You cannot send messages to a blocked user', isError: true);
      return;
    }


    final data = {
      'senderRole': widget.currentUserRole.name, // 🧠 Uses dynamic role
      'msgText': text,
      'replyToMessageId': _replyingToMessageId,
      'replyToText': _replyingToMessageText,
      'replyToSender': _replyingToSender,
    };


    try {
      setState(() => _isSending = true);
      print('--- CHAT DEBUG: Sending started ---');
      
      await _messagingService.sendMessage(widget.conversationId, widget.customerId, data);
      
      print('--- CHAT DEBUG: Message sent successfully! ---');
      _showTopNotification('Message sent successfully!');
      
      _messageController.clear();
      _clearReply();
      _messagingService.setTypingStatus(widget.conversationId, widget.customerId, false);
      _typingTimer?.cancel();
      _scrollToBottom();
    } catch (e) {
      print('--- CHAT DEBUG: Send failed! Error: $e ---');
      _showTopNotification('Send Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Block Functions ─────────────────────────────────────────────────

  Future<void> _blockUser() async {
    try {
      await _messagingService.blockConversationByConversationId(widget.conversationId);
      setState(() => _isBlocked = true);
      _showTopNotification('${widget.otherUserName} has been blocked');
      Navigator.pop(context);
    } catch (e) {
      _showTopNotification('Failed to block user', isError: true);
    }
  }

  Future<void> _unblockUser() async {
    try {
      await _messagingService.unblockConversationByConversationId(widget.conversationId);
      setState(() => _isBlocked = false);
      _showTopNotification('${widget.otherUserName} has been unblocked');
    } catch (e) {
      _showTopNotification('Failed to unblock user', isError: true);
    }
  }

  // ─── Message Options ─────────────────────────────────────────────────

  void _showMessageOptions(Message message) {
    setState(() => _selectedMessageId = message.id);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionOption(
                      icon: Icons.reply,
                      label: 'Reply',
                      onTap: () {
                        Navigator.pop(context);
                        _setReplyToMessage(message);
                      },
                    ),
                    _buildActionOption(
                      icon: Icons.copy,
                      label: 'Copy',
                      onTap: () {
                        Navigator.pop(context);
                        _copyMessage(message);
                      },
                    ),
                    if (message.senderId == widget.customerId)
                    _buildActionOption(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(message);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      setState(() => _selectedMessageId = null);
    });
  }

  Widget _buildActionOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  void _setReplyToMessage(Message message) {
    setState(() {
      _replyingToMessageId = message.id;
      _replyingToMessageText = message.msgText.isEmpty && message.attachment != null ? 'Image' : message.msgText;
      _replyingToSender = message.senderId == widget.customerId ? 'You' : widget.otherUserName;
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToMessageText = null;
      _replyingToSender = null;
    });
  }

  void _copyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.msgText));
    _showTopNotification('Message copied to clipboard');
  }

  void _showDeleteConfirmation(Message message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _messagingService.deleteMessageByMessageId(message.id);
                _showTopNotification('Message deleted');
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // ─── Image/Attachment Functions ──────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) _uploadAndSend(File(image.path), 'image');
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) _uploadAndSend(File(image.path), 'image');
  }

  Future<void> _uploadAndSend(File file, String type, {String? fileName}) async {
    setState(() => _isUploading = true);
    try {
      final url = await _messagingService.uploadAttachmentFile(file);
      if (url != null) {
        // 🧠 Detect current user's role from the opposite of otherUserRole 
        // Or better, we should probably have a role field in this screen too.
        // For now, let's use a safe logic:
        final senderRole = (widget.otherUserRole == UserRole.customer) 
            ? (widget.otherUserId.startsWith('t') ? UserRole.retailer : UserRole.tailor)
            : UserRole.customer;


        final data = {
          'senderRole': senderRole.name,
          'msgText': type == 'document' ? '📄 ${fileName ?? 'Document'}' : '',
          'attachment': url,
        };
        await _messagingService.sendMessage(widget.conversationId, widget.customerId, data);
        _scrollToBottom();
      }
    } catch (e) {
      _showTopNotification('Upload failed', isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _takePhoto();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helper Functions ─────────────────────────────────────────────────

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatDate(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
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

  // ─── Build Methods ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: (widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty)
                  ? NetworkImage(widget.otherUserAvatar!) as ImageProvider
                  : null,
              child: (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty)
                  ? Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<bool>(
                    stream: _otherUserTypingStream,
                    builder: (context, snapshot) {
                      final isTyping = snapshot.data ?? false;
                      return Text(
                        isTyping ? 'typing...' : (_isBlocked ? 'Blocked' : 'Online'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isTyping ? Colors.green[200] : (_isBlocked ? Colors.red[200] : Colors.white70),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C5C44),
        actions: [
          IconButton(
            icon: Icon(_isBlocked ? Icons.block : Icons.more_vert, color: Colors.white),
            onPressed: _isBlocked ? _unblockUser : _showMoreOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF2C5C44)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyChat();
                }
                
                final messages = snapshot.data!;
                
                // 🧠 Auto-scroll only when a new message arrives
                _scrollToBottom();
                
                _markAsRead();
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isFromMe = message.senderId == widget.customerId;
                    final bool showDate = index == 0 ||
                        messages[index - 1].sentAt.day != message.sentAt.day;
                    return Column(
                      children: [
                        if (showDate) _buildDateDivider(message.sentAt),
                        _buildMessageBubble(message, isFromMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF2C5C44)),
          if (_replyingToMessageId != null) _buildReplyIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chat Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _blockUser();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          Text('Start a conversation with ${widget.otherUserName}', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey[200]?.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
      child: Text(_formatDate(date), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildMessageBubble(Message message, bool isFromMe) {
    final hasImage = message.attachment != null && message.attachment!.isNotEmpty;
    final isSelected = _selectedMessageId == message.id;
    
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isFromMe ? Colors.green[200] : Colors.blue[50])
                : (isFromMe ? const Color(0xFFDCF8C6) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isFromMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isFromMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.replyToMessageId != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: isFromMe ? Colors.green : Colors.grey, width: 4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.replyToSender ?? '', style: TextStyle(fontSize: 11, color: isFromMe ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                      Text(message.replyToText ?? '', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              if (hasImage)
                GestureDetector(
                  onTap: () => _showImageFullScreen(message.attachment!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.attachment!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : Container(height: 150, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                    ),
                  ),
                ),
              if (message.msgText.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: hasImage ? 4 : 0),
                  child: Text(message.msgText, style: const TextStyle(fontSize: 14)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatTime(message.sentAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    if (isFromMe) ...[
                      const SizedBox(width: 4),
                      Icon(message.isRead ? Icons.done_all : Icons.done, size: 14, color: message.isRead ? Colors.blue : Colors.grey),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to $_replyingToSender', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(_replyingToMessageText ?? '', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearReply),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFFF0F0F0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _showAttachmentOptions),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                onChanged: _onTyping,
                decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                maxLines: null,
              ),
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF2C5C44), shape: BoxShape.circle),
              child: _isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
