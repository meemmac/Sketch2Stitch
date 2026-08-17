// lib/screens/customer/messaging/chat_screen.dart
import 'dart:async';  // ← Add this import for StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/messaging_service.dart';
import 'package:sketch2stitch/services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String customerId;
  final String otherUserId;
  final String otherUserName;
  final UserRole otherUserRole;
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
    this.otherUserAvatar,
    this.orderId,
    this.onConversationRead,
    this.isBlocked,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  final MessagingService _messagingService = MessagingService();
  final AuthService _authService = AuthService();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  bool _isBlocked = false;
  String? _currentUserId;
  UserRole? _currentUserRole;
  
  // Reply tracking
  String? _replyingToMessageId;
  String? _replyingToMessageText;
  String? _replyingToSender;
  
  String? _selectedMessageId;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;

  // Overlay notification
  OverlayEntry? _notificationOverlay;

  // Firestore subscriptions
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    
    _currentUserId = _authService.currentUser?.uid ?? widget.customerId;
    _currentUserRole = UserRole.customer;
    _isBlocked = widget.isBlocked ?? false;
    
    _loadConversationStatus();
    _loadMessages();
    _listenToTypingStatus();
    _markConversationAsRead();
    
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
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingAnimationController.dispose();
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _conversationSubscription?.cancel();
    _removeNotificationOverlay();
    _markConversationAsRead();
    super.dispose();
  }

  // ─── Load Conversation Status ─────────────────────────────────────────────

  Future<void> _loadConversationStatus() async {
    try {
      final conversation = await _messagingService.getConversationByConversationId(
        widget.conversationId,
      );
      if (conversation != null && mounted) {
        setState(() {
          _isBlocked = conversation.isBlocked;
        });
      }
    } catch (e) {
      debugPrint('Error loading conversation status: $e');
    }
  }

  // ─── Firestore Listeners ──────────────────────────────────────────────────

  void _loadMessages() {
    setState(() => _isLoading = true);

    _messagesSubscription = _messagingService
        .getMessagesByConversationId(widget.conversationId)
        .listen((messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
              _isLoading = false;
            });
            _scrollToBottom();
          }
        }, onError: (error) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showTopNotification('Failed to load messages', isError: true);
          }
        });
  }

  void _listenToTypingStatus() {
    _typingSubscription = _messagingService
        .streamTypingStatus(widget.conversationId, widget.otherUserId)
        .listen((isTyping) {
          if (mounted) {
            setState(() {
              _isTyping = isTyping;
            });
          }
        });
  }

  // ─── Typing Status ─────────────────────────────────────────────────────────

  void _onTypingChanged(String value) {
    _messagingService.setTypingStatus(
      widget.conversationId,
      widget.customerId,
      value.isNotEmpty,
    );
  }

  // ─── Top Notification System ──────────────────────────────────────────────

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

  // ─── Mark as Read ──────────────────────────────────────────────────────────

  Future<void> _markConversationAsRead() async {
    try {
      // Mark conversation as read
      await _messagingService.markConversationReadByConversationId(
        widget.conversationId,
      );
      
      // Mark individual messages as read
      await _messagingService.markMessagesRead(
        widget.conversationId,
        widget.customerId,
      );
      
      if (widget.onConversationRead != null) {
        widget.onConversationRead!(widget.conversationId);
      }
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  // ─── Send Message ─────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isBlocked) {
      _showTopNotification('You cannot send messages to a blocked user', isError: true);
      return;
    }

    // Clear typing status
    _messagingService.setTypingStatus(
      widget.conversationId,
      widget.customerId,
      false,
    );

    // Clear input and reply
    _messageController.clear();
    final replyId = _replyingToMessageId;
    final replyText = _replyingToMessageText;
    final replySender = _replyingToSender;
    setState(() {
      _replyingToMessageId = null;
      _replyingToMessageText = null;
      _replyingToSender = null;
    });

    try {
      final messageData = {
        'msgText': text,
        'senderRole': _currentUserRole?.name ?? UserRole.customer.name,
        'replyToMessageId': replyId,
        'replyToText': replyText,
        'replyToSender': replySender,
      };

      await _messagingService.sendMessage(
        widget.conversationId,
        widget.customerId,
        messageData,
      );
    } catch (e) {
      _showTopNotification('Failed to send message', isError: true);
    }
  }

  // ─── Block Functions ──────────────────────────────────────────────────────

  Future<void> _blockUser() async {
    try {
      await _messagingService.blockConversationByConversationId(
        widget.conversationId,
      );
      
      setState(() {
        _isBlocked = true;
      });
      
      _showTopNotification('${widget.otherUserName} has been blocked');
      
      if (widget.onConversationRead != null) {
        widget.onConversationRead!(widget.conversationId);
      }
      
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    } catch (e) {
      _showTopNotification('Failed to block user', isError: true);
    }
  }

  Future<void> _unblockUser() async {
    try {
      await _messagingService.unblockConversationByConversationId(
        widget.conversationId,
      );
      
      setState(() {
        _isBlocked = false;
      });
      
      _showTopNotification('${widget.otherUserName} has been unblocked');
      
      if (widget.onConversationRead != null) {
        widget.onConversationRead!(widget.conversationId);
      }
    } catch (e) {
      _showTopNotification('Failed to unblock user', isError: true);
    }
  }

  // ─── Message Options ──────────────────────────────────────────────────────

  void _showMessageOptions(Message message) {
    setState(() {
      _selectedMessageId = message.id;
    });
    
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
      setState(() {
        _selectedMessageId = null;
      });
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
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _setReplyToMessage(Message message) {
    setState(() {
      _replyingToMessageId = message.id;
      _replyingToMessageText = message.msgText;
      _replyingToSender = message.senderId == widget.customerId ? 'You' : widget.otherUserName;
      _selectedMessageId = null;
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
    setState(() {
      _selectedMessageId = null;
    });
  }

  void _showDeleteConfirmation(Message message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      await _messagingService.deleteMessageByMessageId(message.id);
      _showTopNotification('Message deleted');
    } catch (e) {
      _showTopNotification('Failed to delete message', isError: true);
    }
  }

  // ─── Image/Attachment Functions ──────────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (image != null) {
      _sendAttachment(File(image.path), 'image');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (image != null) {
      _sendAttachment(File(image.path), 'image');
    }
  }

  Future<void> _pickDocument() async {
    // Use image picker for documents
    final XFile? document = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (document != null) {
      final fileName = document.path.split('/').last;
      _sendAttachment(File(document.path), 'document', fileName: fileName);
    }
  }

  Future<void> _sendAttachment(File file, String type, {String? fileName}) async {
    if (_isBlocked) {
      _showTopNotification('Cannot send messages to blocked user', isError: true);
      return;
    }

    try {
      // Show uploading indicator
      _showTopNotification('Uploading attachment...');
      
      // Upload to Cloudinary
      final imageUrl = await _messagingService.uploadAttachmentFile(file);
      
      if (imageUrl == null) {
        _showTopNotification('Failed to upload attachment', isError: true);
        return;
      }

      final messageText = type == 'document' ? '📄 $fileName' : '';
      
      final messageData = {
        'msgText': messageText,
        'senderRole': _currentUserRole?.name ?? UserRole.customer.name,
        'attachment': imageUrl,
      };

      await _messagingService.sendMessage(
        widget.conversationId,
        widget.customerId,
        messageData,
      );
      
      _removeNotificationOverlay();
    } catch (e) {
      _showTopNotification('Failed to send attachment', isError: true);
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
                const Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                    _buildAttachmentOption(
                      icon: Icons.insert_drive_file,
                      label: 'Document',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _pickDocument();
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
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
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

  // ─── Dialog Functions ─────────────────────────────────────────────────────

  void _showBlockConfirmation() {
    if (_isBlocked) {
      _showUnblockConfirmation();
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Block User'),
          content: Text(
            'Are you sure you want to block ${widget.otherUserName}?\n\n'
            'You will no longer receive messages from this user.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _blockUser();
              },
              child: const Text(
                'Block',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUnblockConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Unblock User'),
          content: Text(
            'Are you sure you want to unblock ${widget.otherUserName}?\n\n'
            'You will start receiving messages from this user again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _unblockUser();
              },
              child: const Text(
                'Unblock',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Clear Chat'),
          content: const Text('Are you sure you want to clear all messages?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Clear messages locally only - Firestore still has them
                setState(() {
                  _messages.clear();
                });
                _showTopNotification('Chat cleared locally');
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMoreOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          title: const Text(
            'Chat Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  _isBlocked ? Icons.block : Icons.block_outlined,
                  color: Colors.red,
                ),
                title: Text(
                  _isBlocked ? 'Unblock User' : 'Block User',
                  style: const TextStyle(color: Colors.red),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  if (_isBlocked) {
                    _showUnblockConfirmation();
                  } else {
                    _showBlockConfirmation();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Clear Chat',
                  style: TextStyle(color: Colors.red),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showClearChatConfirmation();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Helper Functions ─────────────────────────────────────────────────────

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatDate(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[time.month - 1]} ${time.day}, ${time.year}';
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

  // ─── Build Methods ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: widget.otherUserRole == UserRole.customer
                  ? Colors.grey[300]
                  : Colors.grey[200],
              backgroundImage: (widget.otherUserRole != UserRole.customer &&
                  widget.otherUserAvatar != null &&
                  widget.otherUserAvatar!.isNotEmpty)
                  ? NetworkImage(widget.otherUserAvatar!)
                  : null,
              child: (widget.otherUserRole == UserRole.customer ||
                  widget.otherUserAvatar == null ||
                  widget.otherUserAvatar!.isEmpty)
                  ? Text(
                widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.otherUserRole == UserRole.customer
                      ? Colors.grey[700]
                      : const Color(0xFF2C5C44),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isTyping ? 'Typing...' : (_isBlocked ? 'Blocked' : ''),
                    style: TextStyle(
                      fontSize: 11,
                      color: _isTyping ? Colors.green[300] : (_isBlocked ? Colors.red[300] : Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C5C44),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isBlocked ? Icons.block : Icons.more_vert,
              color: Colors.white,
            ),
            onPressed: _isBlocked ? _showUnblockConfirmation : _showMoreOptions,
          ),
        ],
      ),
      body: _isBlocked
          ? _buildBlockedScreen()
          : Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2C5C44),
              ),
            )
                : _messages.isEmpty
                ? _buildEmptyChat()
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final message = _messages[index];
                final isFromMe = message.senderId == widget.customerId;
                final bool showDate = index == 0 ||
                    _messages[index - 1].sentAt.day != message.sentAt.day;
                return Column(
                  children: [
                    if (showDate) _buildDateDivider(message.sentAt),
                    _buildMessageBubble(message, isFromMe),
                  ],
                );
              },
            ),
          ),
          if (_replyingToMessageId != null)
            _buildReplyIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildBlockedScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'You have blocked ${widget.otherUserName}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You will not receive messages from this user',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _showUnblockConfirmation,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text(
              'Unblock User',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with ${widget.otherUserName}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final label = _formatDate(date);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200]?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isFromMe) {
    final hasImage = message.attachment != null && message.attachment!.isNotEmpty;
    final hasText = message.msgText.isNotEmpty;
    final isDocument = hasImage && message.msgText.contains('📄');
    final isSelected = _selectedMessageId == message.id;
    
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
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
              border: isSelected ? Border.all(
                color: isFromMe ? Colors.green : Colors.blue,
                width: 2,
              ) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reply indicator
                if (message.replyToMessageId != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isFromMe ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: isFromMe ? Colors.green : Colors.grey,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyToSender ?? 'You',
                          style: TextStyle(
                            fontSize: 11,
                            color: isFromMe ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          message.replyToText ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                
                // Image
                if (hasImage && !isDocument)
                  GestureDetector(
                    onTap: () => _showImageFullScreen(message.attachment!),
                    child: Container(
                      margin: EdgeInsets.only(bottom: hasText ? 4 : 0),
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message.attachment!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 150,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Document
                if (isDocument)
                  GestureDetector(
                    onTap: () {
                      _showTopNotification('Opening document...');
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: hasText ? 4 : 0),
                      width: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, size: 32, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Document',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  message.msgText.replaceAll('📄 ', ''),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Text
                if (hasText)
                  Text(
                    message.msgText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                
                // Time and read receipt inside the bubble
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(message.sentAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      if (isFromMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead ? Colors.blue : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _typingAnimation,
              builder: (context, child) {
                return Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Opacity(
                        opacity: _typingAnimation.value,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Opacity(
                        opacity: _typingAnimation.value * 0.6,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Opacity(
                        opacity: _typingAnimation.value * 0.3,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.reply,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Replying to $_replyingToSender',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  _replyingToMessageText ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _clearReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    if (_isBlocked) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey[200],
        child: const Center(
          child: Text(
            'You cannot send messages to a blocked user',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                onChanged: (value) {
                  setState(() {});
                  _onTypingChanged(value);
                },
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2C5C44),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: _messageController.text.isNotEmpty ? _sendMessage : null,
          ),
        ],
      ),
    );
  }
}