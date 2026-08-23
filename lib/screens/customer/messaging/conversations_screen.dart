// lib/screens/customer/messaging/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/conversation.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:sketch2stitch/services/messaging_service.dart';

class ConversationsScreen extends StatefulWidget {
  final String customerId;
  final UserRole currentUserRole;

  const ConversationsScreen({
    super.key,
    required this.customerId,
    this.currentUserRole = UserRole.customer,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  final MessagingService _messagingService = MessagingService();
  
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _fetchingIds = {};

  late TabController _tabController;
  String _selectedTab = "All";
  OverlayEntry? _notificationOverlay;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.currentUserRole == UserRole.customer ? 4 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        if (widget.currentUserRole == UserRole.customer) {
          switch (_tabController.index) {
            case 0: _selectedTab = "All"; break;
            case 1: _selectedTab = "Unread"; break;
            case 2: _selectedTab = "Tailors"; break;
            case 3: _selectedTab = "Retailers"; break;
          }
        } else {
          switch (_tabController.index) {
            case 0: _selectedTab = "All"; break;
            case 1: _selectedTab = "Unread"; break;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _removeNotificationOverlay();
    super.dispose();
  }

  // ─── User Data Management ──────────────────────────────────────────

  Future<void> _fetchUserInfo(Conversation conversation) async {
    final String myId = widget.customerId;
    final String targetId = (conversation.customerId == myId) ? conversation.otherId : conversation.customerId;
    final UserRole targetRole = (conversation.customerId == myId) ? conversation.otherRole : UserRole.customer;

    final String cacheKey = "${targetId}_${targetRole.name}";
    if (_userCache.containsKey(cacheKey) || _fetchingIds.contains(cacheKey)) return;

    _fetchingIds.add(cacheKey);
    final info = await _messagingService.getUserBasicInfo(targetId, targetRole);
    if (info != null && mounted) {
      setState(() {
        _userCache[cacheKey] = info;
        _fetchingIds.remove(cacheKey);
      });
    } else {
      _fetchingIds.remove(cacheKey);
    }
  }

  String _getOtherUserName(Conversation conversation) {
    final String myId = widget.customerId;
    final String targetId = (conversation.customerId == myId) ? conversation.otherId : conversation.customerId;
    final UserRole targetRole = (conversation.customerId == myId) ? conversation.otherRole : UserRole.customer;
    final String cacheKey = "${targetId}_${targetRole.name}";
    return _userCache[cacheKey]?['name'] ?? 'Loading...';
  }

  String? _getOtherUserAvatar(Conversation conversation) {
    final String myId = widget.customerId;
    final String targetId = (conversation.customerId == myId) ? conversation.otherId : conversation.customerId;
    final UserRole targetRole = (conversation.customerId == myId) ? conversation.otherRole : UserRole.customer;
    final String cacheKey = "${targetId}_${targetRole.name}";
    return _userCache[cacheKey]?['profilePicture'];
  }

  // ─── Notification System ────────────────────────────────────────────

  void _showTopNotification(String message, {bool isError = false}) {
    _removeNotificationOverlay();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: isError ? Colors.red[700] : const Color(0xFF2D8D3D), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 3))]),
              child: Row(
                children: [
                  Icon(isError ? Icons.error_outline : Icons.notifications_active, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
                  GestureDetector(onTap: _removeNotificationOverlay, child: const Icon(Icons.close, color: Colors.white, size: 18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    _notificationOverlay = entry;
    Future.delayed(const Duration(seconds: 2), _removeNotificationOverlay);
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  // ─── Helper Methods ────────────────────────────────────────────────

  String _getTimeAgo(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 7) return '${difference.inDays ~/ 7}w';
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Now';
  }

  // ─── Backend Actions ────────────────────────────────────────────────

  Future<void> _unblockUser(Conversation conversation) async {
    try {
      await _messagingService.unblockConversationByConversationId(conversation.id);
      _showTopNotification('${_getOtherUserName(conversation)} unblocked');
    } catch (e) {
      _showTopNotification('Failed to unblock', isError: true);
    }
  }

  Future<void> _blockUser(Conversation conversation) async {
    try {
      await _messagingService.blockConversationByConversationId(conversation.id, widget.customerId);
      _showTopNotification('${_getOtherUserName(conversation)} blocked');
    } catch (e) {
      _showTopNotification('Failed to block', isError: true);
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    try {
      await _messagingService.deleteConversationByConversationId(conversation.id);
      _showTopNotification('Conversation deleted');
    } catch (e) {
      _showTopNotification('Failed to delete', isError: true);
    }
  }

  // ─── Navigation ──────────────────────────────────────────────────

  void _openChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          customerId: widget.customerId,
          otherUserId: conversation.customerId == widget.customerId ? conversation.otherId : conversation.customerId,
          otherUserName: _getOtherUserName(conversation),
          otherUserRole: conversation.otherRole,
          currentUserRole: widget.currentUserRole,
          otherUserAvatar: _getOtherUserAvatar(conversation),
          orderId: conversation.orderId,
          isBlocked: conversation.isBlocked,
          blockedBy: conversation.blockedBy,
        ),
      ),
    );
  }

  // ─── Main Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String myId = widget.customerId.trim();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2C5C44),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF2C5C44),
            child: TabBar(
              controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
              tabs: widget.currentUserRole == UserRole.customer
                  ? const [Tab(text: 'All'), Tab(text: 'Unread'), Tab(text: 'Tailors'), Tab(text: 'Retailers')]
                  : const [Tab(text: 'All'), Tab(text: 'Unread')],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _messagingService.getConversations(widget.customerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2C5C44)));
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) return _buildEmptyState();

          final filtered = conversations.where((conv) {
            if (conv.isDeleted) return false;
            final bool isUnread = (conv.unreadCounts[myId] ?? 0) > 0;
            if (_selectedTab == "Unread") return isUnread;
            if (widget.currentUserRole == UserRole.customer) {
              if (_selectedTab == "Tailors" && conv.otherRole != UserRole.tailor) return false;
              if (_selectedTab == "Retailers" && conv.otherRole != UserRole.retailer) return false;
            }
            return true;
          }).toList();

          if (filtered.isEmpty) return _buildEmptyFilterState();

          return ListView.builder(
            itemCount: filtered.length, padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final conversation = filtered[index];
              _fetchUserInfo(conversation);
              return _buildConversationCard(conversation);
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    final otherName = _getOtherUserName(conversation);
    final otherAvatar = _getOtherUserAvatar(conversation);
    final Color primaryGreen = const Color(0xFF2C5C44);
    final Color unreadBg = const Color(0xFFF1F8F1);
    
    final String myId = widget.customerId.trim();
    final String lastSenderId = (conversation.lastSenderId ?? '').trim();
    final String partnerId = conversation.customerId.trim() == myId ? conversation.otherId.trim() : conversation.customerId.trim();

    final int myUnreadCount = conversation.unreadCounts[myId] ?? 0;
    final int partnerUnreadCount = conversation.unreadCounts[partnerId] ?? 0;

    final bool isUnread = myUnreadCount > 0;
    final bool iAmLastSender = lastSenderId == myId;

    /// 🧠 Logic-based Ticks: If I sent the latest message, it is Seen only when the recipient's unread count is 0.
    final bool lastMessageIsRead = iAmLastSender && partnerUnreadCount == 0;

    return GestureDetector(
      onTap: () => _openChat(conversation),
      onLongPress: () => _showConversationOptions(conversation),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUnread ? unreadBg : Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: isUnread ? primaryGreen.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: isUnread ? Border.all(color: primaryGreen.withValues(alpha: 0.2), width: 2) : Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30, backgroundColor: Colors.grey[200], backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
                  child: otherAvatar == null ? Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)) : null,
                ),
                if (isUnread) Positioned(right: 0, bottom: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(otherName, style: TextStyle(fontSize: 17, fontWeight: isUnread ? FontWeight.w900 : FontWeight.w600, color: isUnread ? primaryGreen : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(_getTimeAgo(conversation.updatedAt), style: TextStyle(fontSize: 12, color: isUnread ? primaryGreen : Colors.grey[500], fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (iAmLastSender && !conversation.isBlocked)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(lastMessageIsRead ? Icons.done_all : Icons.done, size: 14, color: lastMessageIsRead ? Colors.blue[400] : Colors.grey),
                        ),
                      Expanded(child: Text(conversation.isBlocked ? '🔒 Blocked' : (conversation.lastMessage ?? 'No messages yet'), style: TextStyle(fontSize: 14, color: isUnread ? Colors.black87 : Colors.grey[600], fontWeight: isUnread ? FontWeight.bold : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (isUnread) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(10)), child: Text(myUnreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConversationOptions(Conversation conversation) {
    final String myId = widget.customerId.trim();
    final bool iBlockedThem = conversation.isBlocked && conversation.blockedBy == myId;
    final bool theyBlockedMe = conversation.isBlocked && conversation.blockedBy != null && conversation.blockedBy != myId;

    showModalBottomSheet(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!conversation.isBlocked)
              ListTile(leading: const Icon(Icons.block, color: Colors.red), title: const Text('Block user', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); _blockUser(conversation); }),
            if (iBlockedThem)
              ListTile(leading: const Icon(Icons.lock_open, color: Colors.green), title: const Text('Unblock user', style: TextStyle(color: Colors.green)), onTap: () { Navigator.pop(context); _unblockUser(conversation); }),
            if (theyBlockedMe)
              const ListTile(leading: Icon(Icons.block, color: Colors.grey), title: Text('You are blocked', style: TextStyle(color: Colors.grey))),
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete conversation'), onTap: () { Navigator.pop(context); _deleteConversation(conversation); }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]), const SizedBox(height: 16), const Text('No messages yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]));
  Widget _buildEmptyFilterState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_alt_off, size: 80, color: Colors.grey[400]), const SizedBox(height: 16), const Text('No results match filter', style: TextStyle(fontSize: 18))]));
}
