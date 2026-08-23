// lib/screens/customer/messaging/chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/messaging/in_app_camera_screen.dart';
import 'package:sketch2stitch/screens/customer/messaging/photo_preview_screen.dart';
import 'package:sketch2stitch/services/messaging_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String customerId; // Represents the logged in user's ID
  final String otherUserId;
  final String otherUserName;
  final UserRole otherUserRole;
  final UserRole currentUserRole;
  final String? otherUserAvatar;
  final bool? isBlocked;
  final String? blockedBy;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.customerId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    required this.currentUserRole,
    this.otherUserAvatar,
    this.isBlocked,
    this.blockedBy,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  late Stream<List<Message>> _messageStream;
  late Stream<bool> _otherUserTypingStream;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _conversationSubscription;

  // Reply tracking
  String? _replyingToMessageId;
  String? _replyingToMessageText;
  String? _replyingToSender;
  
  String? _selectedMessageId;
  
  bool _isBlocked = false;
  String? _blockedBy; 
  bool _isUploading = false;
  bool _isSending = false;
  bool _isPickingImage = false;
  Timer? _typingTimer;

  late String _activeConversationId;
  bool _isNewChat = false;

  OverlayEntry? _notificationOverlay;

  // Read receipts must not fire while the app is backgrounded with the chat open.
  bool _isForeground = true;
  // Guards the TEMP -> real conversation upgrade against a concurrent
  // text send and photo send both creating a thread.
  Future<String>? _conversationCreation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isBlocked = widget.isBlocked ?? false;
    _blockedBy = widget.blockedBy;
    _activeConversationId = widget.conversationId;
    _isNewChat = _activeConversationId.startsWith('TEMP-');

    _messageStream = _messagingService.getMessagesByConversationId(_activeConversationId, widget.customerId);
    _otherUserTypingStream = _messagingService.streamTypingStatus(_activeConversationId, widget.otherUserId);
    
    if (!_isNewChat) {
      _attachLiveListeners();
      // Mark as read immediately when screen opens (eager read on first frame)
      WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
    }

    _retrieveLostData();
  }

  Future<void> _retrieveLostData() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final LostDataResponse response = await _imagePicker.retrieveLostData();
        if (response.isEmpty) return;
        if (response.file != null && mounted) {
          _openPhotoPreview(File(response.file!.path), ImageSource.camera);
        } else if (response.exception != null) {
          debugPrint('ImagePicker lost data exception: ${response.exception}');
        }
      } catch (e) {
        debugPrint('Error retrieving lost data: $e');
      }
    }
  }

  bool _previewOpened = false;

  void _openPhotoPreview(File file, ImageSource source) {
    if (_previewOpened) return;
    _previewOpened = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoPreviewScreen(
          initialFile: file,
          source: source,
          onSend: (selectedFile, caption) {
            _uploadAndSend(selectedFile, 'image', caption: caption);
          },
        ),
      ),
    ).then((_) {
      _previewOpened = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) _markAsRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _conversationSubscription?.cancel();
    _typingTimer?.cancel();
    // Otherwise the other side sees a stale "typing..." forever.
    if (!_isNewChat) {
      _messagingService.setTypingStatus(_activeConversationId, widget.customerId, false);
    }
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _removeNotificationOverlay();
    super.dispose();
  }

  void _markAsRead() {
    if (_isNewChat || !_isForeground) return;
    _messagingService.markMessagesRead(_activeConversationId, widget.customerId);
  }

  void _attachLiveListeners() {
    _messageSubscription?.cancel();
    _conversationSubscription?.cancel();

    _messageSubscription = _messageStream.listen((messages) {
      if (!mounted || messages.isEmpty) return;
      final bool hasUnread = messages.any((m) => m.senderId != widget.customerId && !m.isRead);
      if (hasUnread) {
        _markAsRead();
      }
    });

    _conversationSubscription = _messagingService.streamConversation(_activeConversationId).listen((conv) {
      if (conv != null && mounted) {
        setState(() {
          _isBlocked = conv.isBlocked;
          _blockedBy = conv.blockedBy;
        });
      }
    });
  }

  void _showTopNotification(String message, {bool isError = false}) {
    _removeNotificationOverlay();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: Material(color: Colors.transparent, child: Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: isError ? Colors.red[700] : const Color.fromARGB(255, 45, 141, 61), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]), child: Row(children: [Icon(isError ? Icons.error_outline : Icons.notifications_active, color: Colors.white, size: 20), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))), GestureDetector(onTap: _removeNotificationOverlay, child: const Icon(Icons.close, color: Colors.white, size: 18))]))))),
    );
    overlay.insert(entry); _notificationOverlay = entry;
    Future.delayed(const Duration(seconds: 2), _removeNotificationOverlay);
  }

  void _removeNotificationOverlay() { _notificationOverlay?.remove(); _notificationOverlay = null; }

  void _onTyping(String text) {
    if (_isNewChat || (_typingTimer?.isActive ?? false)) return;
    _messagingService.setTypingStatus(_activeConversationId, widget.customerId, true);
    _typingTimer = Timer(const Duration(seconds: 3), () { _messagingService.setTypingStatus(_activeConversationId, widget.customerId, false); });
  }

  /// Creates the real conversation for a TEMP- thread exactly once, even if a
  /// text send and a photo send race each other.
  Future<String> _ensureConversation() async {
    if (!_isNewChat) return _activeConversationId;
    _conversationCreation ??= () async {
      try {
        final newConv = await _messagingService.createConversation(
          customerId: widget.customerId,
          otherId: widget.otherUserId,
          otherRole: widget.otherUserRole,
          customerRole: widget.currentUserRole,
        );
        return newConv.id;
      } catch (e) {
        // Don't cache a failed attempt — the next send must retry.
        _conversationCreation = null;
        rethrow;
      }
    }();

    final newId = await _conversationCreation!;

    // Assigned before the mounted check so a send that outlives the widget
    // still targets the real conversation instead of the TEMP- placeholder.
    _activeConversationId = newId;
    _isNewChat = false;

    if (!mounted) return newId;
    setState(() {
      _messageStream = _messagingService.getMessagesByConversationId(newId, widget.customerId);
      _otherUserTypingStream =
          _messagingService.streamTypingStatus(newId, widget.otherUserId);
    });
    _attachLiveListeners();
    return newId;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_isBlocked) {
      final String myId = widget.customerId.trim();
      final String msg = (_blockedBy == myId) ? 'You have blocked this user. Unblock to send messages.' : 'You cannot send messages to this user.';
      _showTopNotification(msg, isError: true); return;
    }
    try {
      setState(() => _isSending = true);
      await _ensureConversation();
      final data = {'senderRole': widget.currentUserRole.name, 'msgText': text, 'replyToMessageId': _replyingToMessageId, 'replyToText': _replyingToMessageText, 'replyToSender': _replyingToSender};
      await _messagingService.sendMessage(_activeConversationId, widget.customerId, data);
      _messageController.clear(); _clearReply(); _messagingService.setTypingStatus(_activeConversationId, widget.customerId, false); _typingTimer?.cancel(); _scrollToBottom(force: true);
    } catch (e) { _showTopNotification('Send Error: $e', isError: true); } finally { if (mounted) setState(() => _isSending = false); }
  }

  void _showBlockConfirmation() {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Block User'), content: Text('Are you sure you want to block ${widget.otherUserName}? You will no longer receive messages from them.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () { Navigator.pop(context); _blockUser(); }, child: const Text('Block', style: TextStyle(color: Colors.red)))]));
  }

  void _showUnblockConfirmation() {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Unblock User'), content: Text('Unblock ${widget.otherUserName} to start messaging again?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () { Navigator.pop(context); _unblockUser(); }, child: const Text('Unblock', style: TextStyle(color: Colors.green)))]));
  }

  Future<void> _blockUser() async {
    if (_isNewChat) return;
    try { 
      await _messagingService.blockConversationByConversationId(_activeConversationId, widget.customerId); 
      if (mounted) { _showTopNotification('${widget.otherUserName} has been blocked'); Navigator.pop(context); }
    } catch (e) { if (mounted) _showTopNotification('Failed to block user', isError: true); }
  }

  Future<void> _unblockUser() async {
    if (_isNewChat) return;
    try { await _messagingService.unblockConversationByConversationId(_activeConversationId); if (mounted) _showTopNotification('${widget.otherUserName} has been unblocked'); }
    catch (e) { if (mounted) _showTopNotification('Failed to unblock user', isError: true); }
  }

  void _showMessageOptions(Message message) {
    setState(() => _selectedMessageId = message.id);
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) {
      return SafeArea(child: Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildActionOption(icon: Icons.reply, label: 'Reply', onTap: () { Navigator.pop(context); _setReplyToMessage(message); }), _buildActionOption(icon: Icons.copy, label: 'Copy', onTap: () { Navigator.pop(context); _copyMessage(message); }), if (message.senderId == widget.customerId) _buildActionOption(icon: Icons.delete_outline, label: 'Delete', color: Colors.red, onTap: () { Navigator.pop(context); _showDeleteConfirmation(message); })])])));
    }).then((_) { setState(() => _selectedMessageId = null); });
  }

  Widget _buildActionOption({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.black87}) {
    return GestureDetector(onTap: onTap, child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 11, color: color))]));
  }

  void _setReplyToMessage(Message message) {
    setState(() { _replyingToMessageId = message.id; _replyingToMessageText = message.msgText.isEmpty && message.attachment != null ? 'Image' : message.msgText; _replyingToSender = message.senderId == widget.customerId ? 'You' : widget.otherUserName; });
    _focusNode.requestFocus();
  }

  void _clearReply() { setState(() { _replyingToMessageId = null; _replyingToMessageText = null; _replyingToSender = null; }); }
  void _copyMessage(Message message) {
    if (message.msgText.trim().isEmpty) {
      _showTopNotification('This message has no text to copy', isError: true);
      return;
    }
    Clipboard.setData(ClipboardData(text: message.msgText));
    _showTopNotification('Message copied to clipboard');
  }

  void _showDeleteConfirmation(Message message) {
    showDialog(context: context, builder: (context) {
      return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete Message'), content: Text('Delete this message for everyone? It will be removed from ${widget.otherUserName}\'s chat too, and this cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () async { Navigator.pop(context); if (!_isNewChat) { await _messagingService.deleteMessageByMessageId(message.id, conversationId: _activeConversationId); _showTopNotification('Message deleted for everyone'); } }, child: const Text('Delete', style: TextStyle(color: Colors.red)))]);
    });
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        if (images.length == 1) {
          // Single image → open preview screen as before
          _openPhotoPreview(File(images.first.path), ImageSource.gallery);
        } else {
          // Multiple images → send all sequentially without preview
          _showTopNotification('Sending ${images.length} photos...');
          for (final img in images) {
            await _uploadAndSend(File(img.path), 'image');
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking images from gallery: $e');
      if (mounted) _showTopNotification('Failed to pick images', isError: true);
    } finally {
      _isPickingImage = false;
    }
  }

  void _takePhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppCameraScreen(
          onSend: (file, caption) {
            _uploadAndSend(file, 'image', caption: caption);
          },
        ),
      ),
    );
  }

  // Cloudinary's free tier rejects very large files, and an unbounded upload
  // burns the quota — reject before spending the round trip.
  static const int _maxAttachmentBytes = 10 * 1024 * 1024; // 10 MB
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'};

  Future<bool> _isAttachmentAllowed(File file) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        _showTopNotification('Unsupported file type', isError: true);
        return false;
      }
      if (await file.length() > _maxAttachmentBytes) {
        _showTopNotification('Image is larger than 10 MB', isError: true);
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Attachment validation failed: $e');
      return false;
    }
  }

  Future<void> _uploadAndSend(File file, String type, {String? fileName, String? caption}) async {
    if (!await _isAttachmentAllowed(file)) return;
    if (!mounted) return;
    if (_isBlocked) {
      _showTopNotification('You cannot send messages to this user.', isError: true);
      return;
    }
    setState(() => _isUploading = true);
    try {
      final url = await _messagingService.uploadAttachmentFile(file);
      if (url == null) {
        if (mounted) _showTopNotification('Upload failed', isError: true);
      } else {
        await _ensureConversation();
        final String messageText = (caption != null && caption.isNotEmpty)
            ? caption
            : (type == 'document' ? '📄 ${fileName ?? 'Document'}' : '');
        final data = {
          'senderRole': widget.currentUserRole.name, 
          'msgText': messageText, 
          'attachment': url,
          'replyToMessageId': _replyingToMessageId,
          'replyToText': _replyingToMessageText,
          'replyToSender': _replyingToSender,
        };
        await _messagingService.sendMessage(_activeConversationId, widget.customerId, data);
        _clearReply();
        _scrollToBottom(force: true);
      }
    } catch (e) { 
      if (mounted) _showTopNotification('Upload failed', isError: true); 
    } finally { 
      if (mounted) setState(() => _isUploading = false); 
    }
  }



  void _showImageFullScreen(String imageUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, elevation: 0, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))), body: Center(child: PhotoView(imageProvider: NetworkImage(imageUrl), minScale: PhotoViewComputedScale.contained, maxScale: PhotoViewComputedScale.covered * 2)))));
  }

  /// There is no presence system, so the app bar shows the contact's role
  /// rather than claiming everyone is permanently "Online".
  String get _roleLabel {
    switch (widget.otherUserRole) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.tailor:
        return 'Tailor';
      case UserRole.retailer:
        return 'Retailer';
    }
  }

  String get _avatarInitial {
    final name = widget.otherUserName.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime time) { final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour); final minute = time.minute.toString().padLeft(2, '0'); final amPm = time.hour >= 12 ? 'PM' : 'AM'; return '$hour:$minute $amPm'; }
  String _formatDate(DateTime time) { final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day); final date = DateTime(time.year, time.month, time.day); final difference = today.difference(date).inDays; if (difference == 0) return 'Today'; if (difference == 1) return 'Yesterday'; final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; return '${months[time.month - 1]} ${time.day}, ${time.year}'; }
  /// True when the view is within a bubble's height of the newest message.
  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < 120;
  }

  /// [force] is for messages the user just sent. Otherwise this respects a
  /// user who has scrolled up to read history instead of yanking them down.
  void _scrollToBottom({bool force = false}) {
    final bool shouldScroll = force || _isAtBottom;
    if (!shouldScroll) return;
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
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: Row(children: [CircleAvatar(radius: 18, backgroundColor: Colors.white24, backgroundImage: (widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty) ? NetworkImage(widget.otherUserAvatar!) as ImageProvider : null, child: (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty) ? Text(_avatarInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.otherUserName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis), StreamBuilder<bool>(stream: _otherUserTypingStream, builder: (context, snapshot) { final isTyping = snapshot.data ?? false; return Text(isTyping ? 'typing...' : (_isBlocked ? 'Blocked' : _roleLabel), style: TextStyle(fontSize: 11, color: isTyping ? Colors.green[200] : (_isBlocked ? Colors.red[200] : Colors.white70))); })]))]),
        backgroundColor: const Color(0xFF2C5C44),
        actions: [if (!_isBlocked || _blockedBy == widget.customerId) IconButton(icon: Icon(_isBlocked ? Icons.lock_open : Icons.more_vert, color: Colors.white), onPressed: _isBlocked ? _showUnblockConfirmation : _showMoreOptions)],
      ),
      body: Column(
        children: [
          Expanded(child: StreamBuilder<List<Message>>(stream: _messageStream, builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2C5C44)));
            final messages = snapshot.data ?? [];
            if (messages.isEmpty) return _buildEmptyChat();
            _scrollToBottom();
            return ListView.builder(controller: _scrollController, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), itemCount: messages.length, itemBuilder: (context, index) { final message = messages[index]; final isFromMe = message.senderId == widget.customerId; final bool showDate = index == 0 || !_isSameDay(messages[index - 1].sentAt, message.sentAt); return Column(children: [if (showDate) _buildDateDivider(message.sentAt), _buildMessageBubble(message, isFromMe)]); });
          })),
          if (_isUploading) const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF2C5C44)),
          if (_replyingToMessageId != null) _buildReplyIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Chat Options'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.block, color: Colors.red), title: const Text('Block User', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); _showBlockConfirmation(); })])));
  }

  Widget _buildEmptyChat() { final displayName = (widget.otherUserName == 'Loading...') ? 'this user' : widget.otherUserName; return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]), const SizedBox(height: 16), Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])), Text('Start a conversation with $displayName', style: TextStyle(fontSize: 14, color: Colors.grey[500]))])); }
  Widget _buildDateDivider(DateTime date) { return Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.grey[200]?.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)), child: Text(_formatDate(date), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500))); }

  Widget _buildMessageBubble(Message message, bool isFromMe) {
    final hasImage = message.attachment != null && message.attachment!.isNotEmpty; final isSelected = _selectedMessageId == message.id;
    return GestureDetector(onLongPress: () => _showMessageOptions(message), child: Align(alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 4), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isSelected ? (isFromMe ? Colors.green[200] : Colors.blue[50]) : (isFromMe ? const Color(0xFFDCF8C6) : Colors.white), borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: isFromMe ? const Radius.circular(16) : const Radius.circular(4), bottomRight: isFromMe ? const Radius.circular(4) : const Radius.circular(16)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (message.replyToMessageId != null) Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: isFromMe ? Colors.green : Colors.grey, width: 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(message.replyToSender ?? '', style: TextStyle(fontSize: 11, color: isFromMe ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)), Text(message.replyToText ?? '', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)])) , if (hasImage) GestureDetector(onTap: () => _showImageFullScreen(message.attachment!), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(message.attachment!, height: 150, width: double.infinity, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : Container(height: 150, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator()))))), if (message.msgText.isNotEmpty) Padding(padding: EdgeInsets.only(top: hasImage ? 4 : 0), child: Text(message.msgText, style: const TextStyle(fontSize: 14))), Padding(padding: const EdgeInsets.only(top: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_formatTime(message.sentAt), style: const TextStyle(fontSize: 10, color: Colors.grey)), if (isFromMe) ...[const SizedBox(width: 4), Icon(message.isRead ? Icons.done_all : Icons.done, size: 14, color: message.isRead ? Colors.blue : Colors.grey)]]))]))));
  }

  Widget _buildReplyIndicator() { return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.grey[100], child: Row(children: [const Icon(Icons.reply, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Replying to $_replyingToSender', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)), Text(_replyingToMessageText ?? '', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)])), IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearReply)])); }

  Widget _buildMessageInput() {
    if (_isBlocked) {
      final String myId = widget.customerId.trim();
      final bool iBlockedThem = _blockedBy == myId;
      final String statusText = iBlockedThem ? 'You blocked this user. Unblock to message.' : 'You cannot message this user.';
      return Container(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(statusText, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)), if (iBlockedThem) TextButton(onPressed: _showUnblockConfirmation, child: const Text('Unblock', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))])));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: const Color(0xFFF0F0F0),
      child: Row(
        children: [
          // Direct Camera Button (Messenger style)
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Color(0xFF2C5C44), size: 24),
            tooltip: 'Camera',
            onPressed: _takePhoto,
          ),
          // Direct Gallery / Attachment Button
          IconButton(
            icon: const Icon(Icons.photo_library, color: Color(0xFF2C5C44), size: 22),
            tooltip: 'Gallery',
            onPressed: _pickImage,
          ),
          // Message Text Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                onChanged: _onTyping,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Send Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2C5C44),
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}

