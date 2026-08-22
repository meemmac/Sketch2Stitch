// lib/screens/customer/messaging/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/conversation.dart';
import 'package:sketch2stitch/models/message.dart';
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
  
  // User data cache to avoid redundant Firestore calls
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

  /// Fetches user info from Firestore and updates cache
  Future<void> _fetchUserInfo(Conversation conversation) async {
    // 🧠 Smart Opposite Party Detection
    final String myId = widget.customerId;
    final String targetId = (conversation.customerId == myId) 
        ? conversation.otherId 
        : conversation.customerId;
    
    final UserRole targetRole = (conversation.customerId == myId)
        ? conversation.otherRole
        : UserRole.customer;

    final String cacheKey = "${targetId}_${targetRole.name}";

    if (_userCache.containsKey(cacheKey) || _fetchingIds.contains(cacheKey)) return;


    _fetchingIds.add(cacheKey);
    final info = await _messagingService.getUserBasicInfo(targetId, targetRole);
    if (info != null) {
      if (mounted) {
        setState(() {
          _userCache[cacheKey] = info;
          _fetchingIds.remove(cacheKey);
        });
      }
    } else {
      _fetchingIds.remove(cacheKey);
    }
  }


  String _getOtherUserName(Conversation conversation) {
    final String myId = widget.customerId;
    final String targetId = (conversation.customerId == myId) 
        ? conversation.otherId 
        : conversation.customerId;
    
    final UserRole targetRole = (conversation.customerId == myId)
        ? conversation.otherRole
        : UserRole.customer;

    final String cacheKey = "${targetId}_${targetRole.name}";
    final userData = _userCache[cacheKey];
    return userData?['name'] ?? 'Loading...';
  }


  String? _getOtherUserAvatar(Conversation conversation) {
    final String myId = widget.customerId;
    final String targetId = (conversation.customerId == myId) 
        ? conversation.otherId 
        : conversation.customerId;

    final UserRole targetRole = (conversation.customerId == myId)
        ? conversation.otherRole
        : UserRole.customer;

    final String cacheKey = "${targetId}_${targetRole.name}";
    final userData = _userCache[cacheKey];
    return userData?['profilePicture'];
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
              decoration: BoxDecoration(
                color: isError ? Colors.red[700] : const Color(0xFF2D8D3D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
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
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
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

  void _onConversationRead(String conversationId) {
    _messagingService.markConversationReadByConversationId(conversationId);
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
      await _messagingService.blockConversationByConversationId(conversation.id);
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

  // ─── Navigation & Dialogs ──────────────────────────────────────────

  void _showNewConversationDialog() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
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
                'New Conversation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setModalState(() => searchQuery = value),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _messagingService.searchUsersByNameOrPhone(searchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = (snapshot.data ?? [])
                        .where((u) => u['id'] != widget.customerId)
                        .toList();
                    if (users.isEmpty) return const Center(child: Text('No users found'));
                    
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final role = UserRole.values.byName(user['role'] ?? 'customer');
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['profilePicture'] != null 
                                ? NetworkImage(user['profilePicture']) 
                                : null,
                            child: user['profilePicture'] == null 
                                ? Text(user['name']?[0] ?? '?') 
                                : null,
                          ),
                          title: Text(user['name'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['phone'] ?? ''),
                              Text(
                                role.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: role == UserRole.tailor ? Colors.blue : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            Navigator.pop(context);
                            
                            // 🧠 Pre-fill the cache so ChatScreen doesn't show "Loading..."
                            final String cacheKey = "${user['id']}_${role.name}";
                            _userCache[cacheKey] = user;

                            final existing = await _messagingService.getConversationBetween(
                              widget.customerId, 
                              user['id'],
                              otherRole: role,
                            );

                            if (existing != null) {
                              _openChat(existing);
                            } else {
                              // 🧠 Create a virtual placeholder conversation
                              // It has an ID but hasn't been saved to Firestore yet.
                              final placeholder = Conversation(
                                id: 'TEMP-${widget.customerId}-${user['id']}',
                                customerId: widget.customerId,
                                otherId: user['id'],
                                otherRole: role,
                                orderId: 'NEW-${DateTime.now().millisecondsSinceEpoch}',
                                updatedAt: DateTime.now(),
                              );
                              _openChat(placeholder);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(Conversation conversation) {
    if (conversation.isBlocked) {
      _showBlockedDialog(conversation);
      return;
    }
    
    // 🛡️ REMOVED: Blind unreadCount reset. 
    // markMessagesRead inside ChatScreen will now handle this safely 
    // by checking if the user is the actual receiver.
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          customerId: widget.customerId,
          otherUserId: conversation.otherId,
          otherUserName: _getOtherUserName(conversation),
          otherUserRole: conversation.otherRole,
          currentUserRole: widget.currentUserRole,
          otherUserAvatar: _getOtherUserAvatar(conversation),
          orderId: conversation.orderId,
          onConversationRead: _onConversationRead,
          isBlocked: conversation.isBlocked,
        ),
      ),
    );
  }

  void _showBlockedDialog(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Blocked'),
        content: Text('${_getOtherUserName(conversation)} is blocked. Unblock to message?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unblockUser(conversation);
            },
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  // ─── Main Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2C5C44),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => showSearch(
              context: context,
              delegate: _ConversationSearchDelegate(
                onConversationTap: _openChat,
                userCache: _userCache,
                messagingService: _messagingService,
                customerId: widget.customerId,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF2C5C44),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: widget.currentUserRole == UserRole.customer
                  ? const [
                      Tab(text: 'All'),
                      Tab(text: 'Unread'),
                      Tab(text: 'Tailors'),
                      Tab(text: 'Retailers'),
                    ]
                  : const [Tab(text: 'All'), Tab(text: 'Unread')],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationDialog,
        backgroundColor: const Color(0xFF2C5C44),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _messagingService.getConversations(widget.customerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2C5C44)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading messages: ${snapshot.error}'));
          }
          
          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) return _buildEmptyState();

          // Apply UI Filters (Tab Selection)
          final filtered = conversations.where((conv) {
            if (conv.isDeleted) return false;
            
            // 🧠 Unread Detection without lastSenderId
            final bool isUnread = conv.unreadCount > 0;
            
            if (_selectedTab == "Unread") return isUnread;
            
            if (widget.currentUserRole == UserRole.customer) {
              if (_selectedTab == "Tailors" && conv.otherRole != UserRole.tailor) return false;
              if (_selectedTab == "Retailers" && conv.otherRole != UserRole.retailer) return false;
            }
            return true;
          }).toList();

          if (filtered.isEmpty) return _buildEmptyFilterState();

          return ListView.builder(
            itemCount: filtered.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final conversation = filtered[index];
              // Background fetch for user details using smart lookup
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
    
    // 🧠 Unread Detection without lastSenderId
    final bool isUnread = conversation.unreadCount > 0;
    
    // 🆕 Visual feedback variables
    final Color unreadBg = const Color(0xFFE8F5E9); // Light green background
    final Color primaryGreen = const Color(0xFF2C5C44);
    final Color unreadBorder = primaryGreen.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: () => _openChat(conversation),
      onLongPress: () => _showConversationOptions(conversation),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUnread ? unreadBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isUnread ? primaryGreen.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: isUnread ? Border.all(color: unreadBorder, width: 2) : Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
                  child: otherAvatar == null 
                      ? Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?', 
                          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)) 
                      : null,
                ),
                if (isUnread)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
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
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: isUnread ? FontWeight.w900 : FontWeight.w600,
                            color: isUnread ? primaryGreen : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _getTimeAgo(conversation.updatedAt),
                        style: TextStyle(
                          fontSize: 12, 
                          color: isUnread ? primaryGreen : Colors.grey[500],
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  StreamBuilder<List<Message>>(
                    stream: _messagingService.getMessagesByConversationId(conversation.id),
                    builder: (context, msgSnap) {
                      final lastMsg = (msgSnap.data != null && msgSnap.data!.isNotEmpty) 
                          ? msgSnap.data!.last 
                          : null;
                      
                      final String msgPreview = conversation.isBlocked 
                            ? '🔒 Blocked' 
                            : (lastMsg?.msgText ?? 'No messages yet');

                      return Row(
                        children: [
                          if (lastMsg != null && lastMsg.senderId == widget.customerId && !conversation.isBlocked)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.done_all, size: 14, color: Colors.blue[400]),
                            ),
                          Expanded(
                            child: Text(
                              msgPreview,
                              style: TextStyle(
                                fontSize: 14,
                                color: isUnread ? Colors.black87 : Colors.grey[600],
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                conversation.unreadCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      );
                    },
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                conversation.isBlocked ? Icons.lock_open : Icons.block,
                color: conversation.isBlocked ? Colors.green : Colors.red,
              ),
              title: Text(conversation.isBlocked ? 'Unblock user' : 'Block user'),
              onTap: () {
                Navigator.pop(context);
                conversation.isBlocked ? _unblockUser(conversation) : _blockUser(conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete conversation'),
              onTap: () {
                Navigator.pop(context);
                _deleteConversation(conversation);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showNewConversationDialog,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C5C44)),
              child: const Text('New Conversation', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  Widget _buildEmptyFilterState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No results match filter', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
}

// ─── Search Delegate ─────────────────────────────────────────────────────

class _ConversationSearchDelegate extends SearchDelegate {
  final Function(Conversation) onConversationTap;
  final Map<String, Map<String, dynamic>> userCache;
  final MessagingService messagingService;
  final String customerId;

  _ConversationSearchDelegate({
    required this.onConversationTap,
    required this.userCache,
    required this.messagingService,
    required this.customerId,
  });

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    return StreamBuilder<List<Conversation>>(
      stream: messagingService.getConversations(customerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final results = snapshot.data!.where((conv) {
          // 🧠 Perspective-Aware Cache Key
          final targetId = (conv.customerId == customerId) ? conv.otherId : conv.customerId;
          final targetRole = (conv.customerId == customerId) ? conv.otherRole : UserRole.customer;
          final cacheKey = "${targetId}_${targetRole.name}";
          
          final name = userCache[cacheKey]?['name']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();

        if (results.isEmpty) return const Center(child: Text('No conversations found'));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final conv = results[index];
            
            final targetId = (conv.customerId == customerId) ? conv.otherId : conv.customerId;
            final targetRole = (conv.customerId == customerId) ? conv.otherRole : UserRole.customer;
            final cacheKey = "${targetId}_${targetRole.name}";
            
            final name = userCache[cacheKey]?['name'] ?? 'User';
            return ListTile(
              title: Text(name),
              subtitle: Text(targetRole.name.toUpperCase()),
              onTap: () {
                close(context, null);
                onConversationTap(conv);
              },
            );
          },
        );
      },
    );
  }
}
