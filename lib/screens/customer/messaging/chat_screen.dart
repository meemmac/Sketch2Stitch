// lib/screens/customer/messaging/chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/models/conversation.dart';

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
  
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  
  // Reply tracking
  String? _replyingToMessageId;
  String? _replyingToMessageText;
  String? _replyingToSender;
  
  String? _selectedMessageId;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  
  // Conversation status
  bool _isBlocked = false;
  bool _isMuted = false;
  DateTime? _mutedUntil;
  Timer? _muteTimer;

  @override
  void initState() {
    super.initState();
    
    // Set initial blocked state from widget parameter
    _isBlocked = widget.isBlocked ?? false;
    
    _loadMessages();
    _loadConversationStatus();
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
    _muteTimer?.cancel();
    _markConversationAsRead();
    super.dispose();
  }

  // ─── Centered Notification ───────────────────────────────────────────

  void _showCenteredNotification(String message, {bool isError = false}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? Colors.red[700] : const Color(0xFF2C5C44),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Load Data ──────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    try {
      // TODO: Replace with API call
      await Future.delayed(const Duration(milliseconds: 500));
      final sampleMessages = _getSampleMessages();
      setState(() {
        _messages = sampleMessages;
        _isLoading = false;
      });
      _scrollToBottom();
      
    } catch (e) {
      setState(() => _isLoading = false);
      _showCenteredNotification('Failed to load messages', isError: true);
    }
  }

  Future<void> _loadConversationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMuted = prefs.getBool('muted_${widget.conversationId}') ?? false;
      final mutedUntilStr = prefs.getString('mutedUntil_${widget.conversationId}');
      
      // Only load blocked status from prefs if not already set from widget
      if (widget.isBlocked == null) {
        final isBlocked = prefs.getBool('blocked_${widget.conversationId}') ?? false;
        setState(() {
          _isBlocked = isBlocked;
        });
      }
      
      if (isMuted && mutedUntilStr != null) {
        final mutedUntil = DateTime.parse(mutedUntilStr);
        if (DateTime.now().isAfter(mutedUntil)) {
          setState(() {
            _isMuted = false;
            _mutedUntil = null;
          });
          await _saveMuteStatus(false, null);
        } else {
          setState(() {
            _isMuted = true;
            _mutedUntil = mutedUntil;
          });
          _startMuteTimer(mutedUntil.difference(DateTime.now()));
        }
      }
      
    } catch (e) {
      print('Error loading conversation status: $e');
    }
  }

  // ─── Mark as Read ──────────────────────────────────────────────────

  Future<void> _markConversationAsRead() async {
    try {
      // TODO: Replace with API call
      // await api.markConversationAsRead(widget.conversationId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_read_${widget.conversationId}',
        DateTime.now().toIso8601String(),
      );
      await prefs.setInt('unread_count_${widget.conversationId}', 0);
      
      if (widget.onConversationRead != null) {
        widget.onConversationRead!(widget.conversationId);
      }
      
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // ─── Send Message ──────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isBlocked) {
      _showCenteredNotification('You cannot send messages to a blocked user', isError: true);
      return;
    }

    final newMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: widget.customerId,
      senderRole: UserRole.customer,
      msgText: text,
      sentAt: DateTime.now(),
      replyToMessageId: _replyingToMessageId,
      replyToText: _replyingToMessageText,
      replyToSender: _replyingToSender,
      isRead: false,
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
      _replyingToMessageId = null;
      _replyingToMessageText = null;
      _replyingToSender = null;
    });
    _scrollToBottom();

    try {
      // TODO: Replace with API call
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
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: widget.conversationId,
            senderId: widget.otherUserId,
            senderRole: widget.otherUserRole,
            msgText: reply,
            sentAt: DateTime.now(),
            isRead: false,
          );

          setState(() {
            _messages.add(replyMessage);
            _isTyping = false;
          });
          _scrollToBottom();
        }
      });
      
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == newMessage.id);
      });
      _showCenteredNotification('Failed to send message', isError: true);
    }
  }

  // ─── Mute Functions ─────────────────────────────────────────────────

  Future<void> _saveMuteStatus(bool isMuted, DateTime? mutedUntil) async {
    try {
      // TODO: Replace with API call
      // await api.updateConversation(
      //   widget.conversationId,
      //   isMuted: isMuted,
      //   mutedUntil: mutedUntil,
      // );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('muted_${widget.conversationId}', isMuted);
      if (mutedUntil != null) {
        await prefs.setString('mutedUntil_${widget.conversationId}', mutedUntil.toIso8601String());
      } else {
        await prefs.remove('mutedUntil_${widget.conversationId}');
      }
      
    } catch (e) {
      print('Error saving mute status: $e');
    }
  }

  void _startMuteTimer(Duration duration) {
    _muteTimer?.cancel();
    _muteTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _isMuted = false;
          _mutedUntil = null;
        });
        _saveMuteStatus(false, null);
        _showCenteredNotification('🔔 Mute expired! Notifications are back.');
      }
    });
  }

  void _setMuteDuration(int duration) {
    final durationMap = {
      1: const Duration(hours: 1),
      2: const Duration(hours: 2),
      3: const Duration(hours: 4),
      4: const Duration(hours: 8),
      5: const Duration(hours: 24),
      6: const Duration(days: 7),
    };
    
    final muteDuration = durationMap[duration] ?? const Duration(hours: 1);
    final mutedUntil = DateTime.now().add(muteDuration);
    
    setState(() {
      _isMuted = true;
      _mutedUntil = mutedUntil;
    });
    
    _saveMuteStatus(true, mutedUntil);
    _startMuteTimer(muteDuration);
    
    String label = '';
    switch (duration) {
      case 1: label = '1 hour'; break;
      case 2: label = '2 hours'; break;
      case 3: label = '4 hours'; break;
      case 4: label = '8 hours'; break;
      case 5: label = '24 hours'; break;
      case 6: label = '7 days'; break;
    }
    
    _showCenteredNotification('🔇 Notifications muted for $label');
  }

  void _toggleMuteNotifications() {
    if (_isMuted) {
      _muteTimer?.cancel();
      setState(() {
        _isMuted = false;
        _mutedUntil = null;
      });
      _saveMuteStatus(false, null);
      _showCenteredNotification('🔔 Notifications unmuted');
    } else {
      _showMuteOptions();
    }
  }

  // ─── Block Functions ─────────────────────────────────────────────────

  Future<void> _blockUser() async {
    try {
      // TODO: Replace with API call
      // await api.updateConversation(
      //   widget.conversationId,
      //   isBlocked: true,
      //   blockedBy: widget.customerId,
      //   blockedAt: DateTime.now(),
      // );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('blocked_${widget.conversationId}', true);
      
      setState(() {
        _isBlocked = true;
      });
      
      _showCenteredNotification('${widget.otherUserName} has been blocked');
      
      // Notify conversation screen that block status changed
      if (widget.onConversationRead != null) {
        widget.onConversationRead!(widget.conversationId);
      }
      
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
      
    } catch (e) {
      _showCenteredNotification('Failed to block user', isError: true);
    }
  }

  Future<void> _unblockUser() async {
    try {
      // TODO: Replace with API call
      // await api.updateConversation(
      //   widget.conversationId,
      //   isBlocked: false,
      //   blockedBy: null,
      //   blockedAt: null,
      // );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('blocked_${widget.conversationId}');
      
      setState(() {
        _isBlocked = false;
      });
      
      _showCenteredNotification('${widget.otherUserName} has been unblocked');
      
      // Notify conversation screen that block status changed
      if (widget.onConversationRead != null) {
        widget.onConversationRead!(widget.conversationId);
      }
      
    } catch (e) {
      _showCenteredNotification('Failed to unblock user', isError: true);
    }
  }

  // ─── Notification System ────────────────────────────────────────────

  // ─── Message Options ─────────────────────────────────────────────────

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
                
                // TODO: Call API to delete message
                // await api.deleteMessage(message.id);
                
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

  // ─── Image/Attachment Functions ──────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (image != null) {
      _sendAttachment(image.path, 'image');
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
      _sendAttachment(image.path, 'image');
    }
  }

  Future<void> _pickDocument() async {
    final XFile? document = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (document != null) {
      final fileName = document.path.split('/').last;
      _sendAttachment(document.path, 'document', fileName: fileName);
    }
  }

  void _sendAttachment(String path, String type, {String? fileName}) {
    if (_isBlocked) {
      _showCenteredNotification('Cannot send messages to blocked user', isError: true);
      return;
    }

    final messageText = type == 'document' ? '📄 $fileName' : '';
    
    final newMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: widget.customerId,
      senderRole: UserRole.customer,
      msgText: messageText,
      attachment: path,
      sentAt: DateTime.now(),
      isRead: false,
    );

    setState(() {
      _messages.add(newMessage);
    });
    _scrollToBottom();

    // TODO: Upload attachment and send message via API
    // await api.sendAttachment(...);
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

  // ─── Dialog Functions ─────────────────────────────────────────────────

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
                setState(() {
                  _messages.clear();
                });
                _showCenteredNotification('Chat cleared');
                
                // TODO: Call API to clear chat
                // await api.clearChat(widget.conversationId);
                
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
    final isSelected = _mutedUntil != null && duration == 0;
    
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
              // ❌ Removed "Delete Conversation" option
            ],
          ),
        );
      },
    );
  }

  // ─── Helper Functions ─────────────────────────────────────────────────

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

  List<Message> _getSampleMessages() {
    return [
      Message(
        id: 'm1',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Hello! How can I help you today? 👋',
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: true,
        readAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 55)),
      ),
      Message(
        id: 'm2',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: 'Hi! I need some help with my order.',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
        isRead: true,
        readAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
      ),
      Message(
        id: 'm3',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Sure! What can I assist you with?',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
        isRead: true,
        readAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
      ),
      Message(
        id: 'm4',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: 'I want to check the status of my order.',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
        isRead: true,
        readAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 35)),
      ),
      Message(
        id: 'm5',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Let me check that for you... 📋',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 35)),
        isRead: true,
        readAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      ),
      Message(
        id: 'm6',
        conversationId: widget.conversationId,
        senderId: widget.otherUserId,
        senderRole: widget.otherUserRole,
        msgText: 'Your order is being processed and will be shipped soon! 🚀',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        isRead: false,
      ),
      Message(
        id: 'm7',
        conversationId: widget.conversationId,
        senderId: widget.customerId,
        senderRole: UserRole.customer,
        msgText: 'Thank you so much! 😊',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 25)),
        isRead: true,
        readAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 20)),
      ),
    ];
  }

  // ─── Build Methods ────────────────────────────────────────────────────

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
                  Text(
                    _isBlocked ? 'Blocked' : '',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isBlocked ? Colors.red[300] : Colors.white70,
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
                
                // Document
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