// lib/screens/customer/messaging/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/models/conversation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String customerId;
  final String otherUserId;
  final String otherUserName;
  final UserRole otherUserRole;
  final String? otherUserAvatar;
  final String? orderId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.customerId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    this.otherUserAvatar,
    this.orderId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  String? _replyingToMessageId;
  String? _replyingToMessageText;
  String? _replyingToSender;
  Message? _selectedMessage;
  bool _isMuted = false;
  int _selectedMuteDuration = 0;
  String? _selectedMessageId;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    
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
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final sampleMessages = [
      Message(
        id: 'm1',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Hello! How can I help you today? 👋',
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Message(
        id: 'm2',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: 'Hi! I need some help with my order.',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
      ),
      Message(
        id: 'm3',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Sure! What can I assist you with?',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
      ),
      Message(
        id: 'm4',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: 'I want to check the status of my order.',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
      ),
      Message(
        id: 'm5',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Let me check that for you... 📋',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 35)),
      ),
      Message(
        id: 'm6',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Your order is being processed and will be shipped soon! 🚀',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      ),
      Message(
        id: 'm7',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: 'Thank you so much! 😊',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 25)),
      ),
    ];

    setState(() {
      _messages = sampleMessages;
      _isLoading = false;
    });

    _scrollToBottom();
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final newMessage = Message(
      id: 'm${_messages.length + 1}',
      conversationId: widget.conversationId,
      senderId: widget.customerId,
      senderRole: UserRole.customer,
      msgText: text,
      sentAt: DateTime.now(),
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
      _replyingToMessageId = null;
      _replyingToMessageText = null;
      _replyingToSender = null;
    });

    _scrollToBottom();

    setState(() => _isTyping = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final replies = [
          'That\'s great! I\'ll take care of it.',
          'Perfect! Let me know if you need anything else.',
          'I understand. I\'ll get back to you shortly.',
          'Thanks for letting me know! 🙌',
          'Sure thing! I\'ll prepare that for you.',
          'Got it! I\'ll update you soon.',
        ];
        final reply = replies[DateTime.now().millisecond % replies.length];
        
        final replyMessage = Message(
          id: 'm${_messages.length + 1}',
          conversationId: widget.conversationId,
          senderId: widget.otherUserId,
          senderRole: widget.otherUserRole,
          msgText: reply,
          sentAt: DateTime.now(),
        );

        setState(() {
          _messages.add(replyMessage);
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (image != null) {
      final newMessage = Message(
        id: 'm${_messages.length + 1}',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: '',
        attachment: image.path,
        sentAt: DateTime.now(),
      );

      setState(() {
        _messages.add(newMessage);
      });
      _scrollToBottom();
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
      final newMessage = Message(
        id: 'm${_messages.length + 1}',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: '',
        attachment: image.path,
        sentAt: DateTime.now(),
      );

      setState(() {
        _messages.add(newMessage);
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickDocument() async {
    // Using image_picker as fallback for document picking on Windows
    final XFile? document = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (document != null) {
      final fileName = document.path.split('/').last;
      final newMessage = Message(
        id: 'm${_messages.length + 1}',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: '📄 $fileName',
        attachment: document.path,
        sentAt: DateTime.now(),
      );

      setState(() {
        _messages.add(newMessage);
      });
      _scrollToBottom();
      _showCenteredNotification('Document shared!');
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

  void _showMessageOptions(Message message) {
    setState(() {
      _selectedMessage = message;
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
                    _buildActionOption(
                      icon: Icons.forward,
                      label: 'Forward',
                      onTap: () {
                        Navigator.pop(context);
                        _forwardMessage(message);
                      },
                    ),
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
    _showCenteredNotification('Message copied to clipboard');
    setState(() {
      _selectedMessageId = null;
    });
  }

  void _showCenteredNotification(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  void _forwardMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Forward Message'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select a contact to forward this message to:'),
              SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text('Contact 1'),
                subtitle: Text('Tailor'),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text('Contact 2'),
                subtitle: Text('Retailer'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showCenteredNotification('Message forwarded!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C5C44),
                foregroundColor: Colors.white,
              ),
              child: const Text('Forward'),
            ),
          ],
        );
      },
    );
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
                setState(() {
                  _messages.removeWhere((m) => m.id == message.id);
                  _selectedMessageId = null;
                });
                _showCenteredNotification('Message deleted');
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

  void _showImageFullScreen(String imagePath) {
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
              imageProvider: FileImage(File(imagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Block User'),
          content: Text('Are you sure you want to block ${widget.otherUserName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                _showCenteredNotification('${widget.otherUserName} has been blocked');
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
                setState(() {
                  _messages.clear();
                });
                _showCenteredNotification('Chat cleared');
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

  // ─── Centered Mute Notifications Dialog ───────────────────────────────

  void _showMuteOptions() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Mute notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMuteOptionDialog('1 hour', 1),
              _buildMuteOptionDialog('2 hours', 2),
              _buildMuteOptionDialog('4 hours', 3),
              _buildMuteOptionDialog('8 hours', 4),
              _buildMuteOptionDialog('24 hours', 5),
              _buildMuteOptionDialog('7 days', 6),
              if (_isMuted)
                _buildMuteOptionDialog('Unmute', 0, isUnmute: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMuteOptionDialog(String label, int duration, {bool isUnmute = false}) {
    final isSelected = _selectedMuteDuration == duration;
    
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (isUnmute) {
          _toggleMuteNotifications();
        } else {
          _setMuteDuration(duration);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[100]!, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isUnmute ? Icons.notifications : Icons.notifications_off,
              color: isUnmute ? Colors.green : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isUnmute ? Colors.green : Colors.black,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFF2C5C44),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _setMuteDuration(int duration) {
    _selectedMuteDuration = duration;
    setState(() {
      _isMuted = true;
    });
    
    String label = '';
    switch (duration) {
      case 1:
        label = '1 hour';
        break;
      case 2:
        label = '2 hours';
        break;
      case 3:
        label = '4 hours';
        break;
      case 4:
        label = '8 hours';
        break;
      case 5:
        label = '24 hours';
        break;
      case 6:
        label = '7 days';
        break;
    }
    
    _showCenteredNotification('Notifications muted for $label');
  }

  void _toggleMuteNotifications() {
    setState(() {
      _isMuted = !_isMuted;
      if (!_isMuted) {
        _selectedMuteDuration = 0;
      }
    });
    _showCenteredNotification(_isMuted ? 'Notifications muted' : 'Notifications unmuted');
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
                  _isMuted ? Icons.notifications_off : Icons.notifications,
                  color: const Color(0xFF2C5C44),
                ),
                title: Text(_isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  if (_isMuted) {
                    _toggleMuteNotifications();
                  } else {
                    _showMuteOptions();
                  }
                },
              ),
              const Divider(),
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
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text(
                  'Block User',
                  style: TextStyle(color: Colors.red),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmation();
                },
              ),
            ],
          ),
        );
      },
    );
  }

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

  String _getRoleEmoji(UserRole role) {
    switch (role) {
      case UserRole.tailor:
        return '🧵';
      case UserRole.retailer:
        return '🏪';
      case UserRole.customer:
        return '👤';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.otherUserAvatar != null
                  ? AssetImage(widget.otherUserAvatar!)
                  : null,
              child: widget.otherUserAvatar == null
                  ? Text(
                      widget.otherUserName.isNotEmpty ? widget.otherUserName[0] : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5C44),
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
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
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
              _isMuted ? Icons.notifications_off : Icons.more_vert,
              color: Colors.white,
            ),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2C5C44),
                    ),
                  )
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
    final isReplying = _replyingToMessageId == message.id;
    
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Reply indicator inside the bubble (like WhatsApp)
              if (isReplying)
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
                        _replyingToSender ?? 'You',
                        style: TextStyle(
                          fontSize: 11,
                          color: isFromMe ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _replyingToMessageText ?? '',
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
              Container(
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
                    if (hasImage && !isDocument)
                      GestureDetector(
                        onTap: () => _showImageFullScreen(message.attachment!),
                        child: Container(
                          margin: EdgeInsets.only(bottom: hasText ? 4 : 0),
                          width: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(message.attachment!),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 150,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, size: 40, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (isDocument)
                      GestureDetector(
                        onTap: () {
                          _showCenteredNotification('Opening document...');
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
                                    Text(
                                      'Document',
                                      style: const TextStyle(
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
                    if (hasText)
                      Text(
                        message.msgText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                      const Icon(
                        Icons.done_all,
                        size: 14,
                        color: Colors.blue,
                      ),
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
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Replying to',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
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
                onChanged: (value) => setState(() {}),
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