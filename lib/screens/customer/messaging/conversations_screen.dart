// lib/screens/customer/messaging/conversations_screen.dart
import 'dart:async';  
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/conversation.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:sketch2stitch/services/messaging_service.dart';
import 'package:sketch2stitch/services/auth_service.dart';
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
  final AuthService _authService = AuthService();

  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  String _searchQuery = "";
  late TabController _tabController;
  String _selectedTab = "All";

  // User data cache
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Firestore subscription
  StreamSubscription? _conversationsSubscription;

  // Overlay notification
  OverlayEntry? _notificationOverlay;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.currentUserRole == UserRole.customer ? 4 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      setState(() {
        if (widget.currentUserRole == UserRole.customer) {
          switch (_tabController.index) {
            case 0:
              _selectedTab = "All";
              break;
            case 1:
              _selectedTab = "Unread";
              break;
            case 2:
              _selectedTab = "Tailors";
              break;
            case 3:
              _selectedTab = "Retailers";
              break;
          }
        } else {
          switch (_tabController.index) {
            case 0:
              _selectedTab = "All";
              break;
            case 1:
              _selectedTab = "Unread";
              break;
          }
        }
        _applyFilter();
      });
    });
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _conversationsSubscription?.cancel();
    _removeNotificationOverlay();
    super.dispose();
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
                color: isError
                    ? Colors.red[700]
                    : const Color.fromARGB(255, 45, 141, 61),
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

  // ─── Load Data ─────────────────────────────────────────────────────────────

  void _loadConversations() {
    setState(() => _isLoading = true);

    _conversationsSubscription = _messagingService
        .getConversations(widget.customerId)
        .listen((conversations) {
          if (mounted) {
            setState(() {
              _conversations = conversations;
              _filteredConversations = conversations;
              _isLoading = false;
            });
            _applyFilter();
            _loadUserProfiles(conversations);
          }
        }, onError: (error) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showTopNotification('Failed to load conversations', isError: true);
          }
        });
  }

  // ─── Load User Profiles from Firestore ──────────────────────────────────

  Future<void> _loadUserProfiles(List<Conversation> conversations) async {
    for (var conv in conversations) {
      if (!_userCache.containsKey(conv.otherId)) {
        try {
          final profile = await _messagingService.getUserProfile(
            conv.otherId,
            conv.otherRole,
          );
          if (profile != null) {
            final name = conv.otherRole == UserRole.retailer 
                ? profile['shopName'] 
                : profile['name'];
            _userCache[conv.otherId] = {
              'name': name ?? conv.otherId,
              'phone': profile['phone'] ?? '',
              'avatar': profile['profilePicture'],
              'role': conv.otherRole,
              'model': profile,
              'isAnonymous': false,
            };
            setState(() {});
          }
        } catch (e) {
          debugPrint('Error loading user profile: $e');
        }
      }
    }
  }

  // ─── Filter Functions ─────────────────────────────────────────────────────

  void _applyFilter() {
    setState(() {
      List<Conversation> filtered = List.from(_conversations);

      // Exclude deleted conversations
      filtered = filtered.where((conv) => !conv.isDeleted).toList();

      // Role-based visibility
      filtered = filtered.where((conv) {
        if (widget.currentUserRole == UserRole.customer) {
          return conv.otherRole == UserRole.tailor ||
              conv.otherRole == UserRole.retailer;
        } else {
          return conv.otherRole == UserRole.customer;
        }
      }).toList();

      // Search filter
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((conv) {
          final userData = _userCache[conv.otherId];
          final userName = userData?['name']?.toString().toLowerCase() ?? '';
          final userPhone = userData?['phone']?.toString().toLowerCase() ?? '';
          final lastMessage = _getLastMessage(conv).toLowerCase();
          final query = _searchQuery.toLowerCase();

          return userName.contains(query) ||
              userPhone.contains(query) ||
              lastMessage.contains(query);
        }).toList();
      }

      switch (_selectedTab) {
        case "Unread":
          filtered = filtered.where((conv) => conv.unreadCount > 0).toList();
          break;
        case "Tailors":
          filtered = filtered
              .where((conv) => conv.otherRole == UserRole.tailor)
              .toList();
          break;
        case "Retailers":
          filtered = filtered
              .where((conv) => conv.otherRole == UserRole.retailer)
              .toList();
          break;
        default:
          break;
      }

      _filteredConversations = filtered;
    });
  }

  // ─── Helper Functions ─────────────────────────────────────────────────────

  String _getOtherUserName(Conversation conversation) {
    final userData = _userCache[conversation.otherId];
    if (userData != null) {
      return userData['name'] ?? conversation.otherId;
    }
    return conversation.otherId;
  }

  String _getOtherUserAvatar(Conversation conversation) {
    final userData = _userCache[conversation.otherId];
    if (userData != null && userData['avatar'] != null) {
      return userData['avatar'];
    }
    return '';
  }

  String _getLastMessage(Conversation conversation) {
    if (conversation.messages == null || conversation.messages!.isEmpty) {
      return 'No messages yet';
    }
    return conversation.messages!.last.msgText;
  }

  DateTime _getLastMessageTime(Conversation conversation) {
    if (conversation.messages == null || conversation.messages!.isEmpty) {
      return conversation.updatedAt ?? DateTime.now();
    }
    return conversation.messages!.last.sentAt;
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 1) {
      return '${difference.inDays}d';
    } else if (difference.inDays == 1) {
      return '1d';
    } else if (difference.inHours > 1) {
      return '${difference.inHours}h';
    } else if (difference.inHours == 1) {
      return '1h';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  // ─── Conversation Actions ─────────────────────────────────────────────────

  void _onConversationRead(String conversationId) {
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(
          unreadCount: 0,
          lastReadAt: DateTime.now(),
        );
      }
      _applyFilter();
    });

    // Mark as read in Firestore
    _messagingService.markConversationReadByConversationId(conversationId);
    _messagingService.markMessagesRead(conversationId, widget.customerId);
  }

  Future<void> _blockUser(Conversation conversation) async {
    try {
      await _messagingService.blockConversationByConversationId(
        conversation.id,
      );
      
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isBlocked: true,
            updatedAt: DateTime.now(),
          );
        }
        _applyFilter();
      });
      
      _showTopNotification('${_getOtherUserName(conversation)} has been blocked');
    } catch (e) {
      _showTopNotification('Failed to block user', isError: true);
    }
  }

  Future<void> _unblockUser(Conversation conversation) async {
    try {
      await _messagingService.unblockConversationByConversationId(
        conversation.id,
      );
      
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isBlocked: false,
            updatedAt: DateTime.now(),
          );
        }
        _applyFilter();
      });
      
      _showTopNotification('${_getOtherUserName(conversation)} has been unblocked');
    } catch (e) {
      _showTopNotification('Failed to unblock user', isError: true);
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    try {
      await _messagingService.deleteConversationByConversationId(
        conversation.id,
      );
      
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isDeleted: true,
            deletedAt: DateTime.now(),
          );
        }
        _applyFilter();
      });
      
      _showTopNotification('Conversation deleted');
    } catch (e) {
      _showTopNotification('Failed to delete conversation', isError: true);
    }
  }

  // ─── New Conversation ─────────────────────────────────────────────────────

  void _showNewConversationDialog() {
    // Search for users from Firestore
    String searchQuery = '';
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.7,
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
                    'New Conversation',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search by name or phone number',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search name or phone...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                  searchResults = [];
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) async {
                      setState(() {
                        searchQuery = value;
                        isSearching = true;
                      });
                      
                      if (value.isNotEmpty) {
                        final results = await _messagingService.searchUsersByNameOrPhone(value);
                        setState(() {
                          searchResults = results
                              .where((r) => r['id'] != widget.customerId)
                              .toList();
                          isSearching = false;
                        });
                      } else {
                        setState(() {
                          searchResults = [];
                          isSearching = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : searchQuery.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Search for users to chat with',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : searchResults.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_search,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No users found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Try a different name or phone number',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: searchResults.length,
                                    itemBuilder: (context, index) {
                                      final user = searchResults[index];
                                      final roleString = user['role'] as String? ?? 'customer';
                                      final role = UserRole.values.firstWhere(
                                        (r) => r.name == roleString,
                                        orElse: () => UserRole.customer,
                                      );
                                      final name = user['name'] ?? user['shopName'] ?? 'Unknown';
                                      final phone = user['phone'] ?? '';
                                      final avatar = user['profilePicture'];

                                      return ListTile(
                                        leading: CircleAvatar(
                                          radius: 24,
                                          backgroundColor: avatar != null
                                              ? Colors.grey[200]
                                              : Colors.grey[300],
                                          backgroundImage: avatar != null
                                              ? NetworkImage(avatar)
                                              : null,
                                          child: avatar == null
                                              ? Text(
                                                  name.isNotEmpty
                                                      ? name[0].toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[700],
                                                  ),
                                                )
                                              : null,
                                        ),
                                        title: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 12,
                                              color: Colors.grey[500],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: role == UserRole.tailor
                                                    ? Colors.green.shade50
                                                    : role == UserRole.retailer
                                                    ? Colors.blue.shade50
                                                    : Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                role.name.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: role == UserRole.tailor
                                                      ? Colors.green.shade700
                                                      : role == UserRole.retailer
                                                      ? Colors.blue.shade700
                                                      : Colors.orange.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey,
                                        ),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final otherId = user['id'];

                                          // Check if conversation already exists
                                          var conversation = await _messagingService
                                              .getConversationBetween(
                                                widget.customerId,
                                                otherId,
                                              );

                                          // If not, create new conversation
                                          if (conversation == null) {
                                            conversation = await _messagingService
                                                .createConversation(
                                                  customerId: widget.customerId,
                                                  otherId: otherId,
                                                  otherRole: role,
                                                  orderId: '',
                                                );
                                          }

                                          // Add to cache
                                          _userCache[otherId] = {
                                            'name': name,
                                            'phone': phone,
                                            'avatar': avatar,
                                            'role': role,
                                            'isAnonymous': false,
                                          };

                                          // Navigate to chat
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatScreen(
                                                conversationId: conversation.id,
                                                customerId: widget.customerId,
                                                otherUserId: otherId,
                                                otherUserName: name,
                                                otherUserRole: role,
                                                otherUserAvatar: avatar,
                                                orderId: conversation.orderId,
                                                onConversationRead: _onConversationRead,
                                                isBlocked: conversation.isBlocked,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Search Delegate ─────────────────────────────────────────────────────

  void _showSearch() {
    showSearch(
      context: context,
      delegate: _ConversationSearchDelegate(
        conversations: _conversations,
        userCache: _userCache,
        getOtherUserName: _getOtherUserName,
        getOtherUserAvatar: _getOtherUserAvatar,
        getLastMessage: _getLastMessage,
        getLastMessageTime: _getLastMessageTime,
        customerId: widget.customerId,
        onConversationTap: (conversation) {
          if (conversation.isBlocked) {
            _showBlockedDialog(conversation);
            return;
          }
          _onConversationRead(conversation.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conversation.id,
                customerId: widget.customerId,
                otherUserId: conversation.otherId,
                otherUserName: _getOtherUserName(conversation),
                otherUserRole: conversation.otherRole,
                otherUserAvatar: _getOtherUserAvatar(conversation),
                orderId: conversation.orderId,
                onConversationRead: _onConversationRead,
                isBlocked: conversation.isBlocked,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBlockedDialog(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('User Blocked'),
          content: Text(
            '${_getOtherUserName(conversation)} is blocked.\n\n'
            'You need to unblock this user to send messages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _unblockUser(conversation);
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

  // ─── Build Methods ────────────────────────────────────────────────────────

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
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearch,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF2C5C44),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2C5C44)),
            )
          : _conversations.where((c) => !c.isDeleted).isEmpty
          ? _buildEmptyState()
          : _filteredConversations.isEmpty
          ? _buildEmptyFilterState()
          : ListView.builder(
              itemCount: _filteredConversations.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final conversation = _filteredConversations[index];
                return _buildConversationCard(conversation);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with a tailor or retailer',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showNewConversationDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Conversation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C5C44),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_alt_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No conversations match',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different filter or search term',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    final otherName = _getOtherUserName(conversation);
    final otherAvatar = _getOtherUserAvatar(conversation);
    final lastMessage = _getLastMessage(conversation);
    final lastTime = _getLastMessageTime(conversation);
    final unreadCount = conversation.unreadCount;
    final isBlocked = conversation.isBlocked;
    final isCustomer = conversation.otherRole == UserRole.customer;

    return GestureDetector(
      onTap: () {
        if (isBlocked) {
          _showBlockedDialog(conversation);
          return;
        }
        _onConversationRead(conversation.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              customerId: widget.customerId,
              otherUserId: conversation.otherId,
              otherUserName: otherName,
              otherUserRole: conversation.otherRole,
              otherUserAvatar: otherAvatar,
              orderId: conversation.orderId,
              onConversationRead: _onConversationRead,
              isBlocked: isBlocked,
            ),
          ),
        );
      },
      onLongPress: () {
        _showConversationOptions(conversation);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: unreadCount > 0 ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isCustomer
                      ? Colors.grey[300]
                      : Colors.grey[200],
                  backgroundImage:
                      (!isCustomer &&
                          otherAvatar != null &&
                          otherAvatar.isNotEmpty)
                      ? (otherAvatar.startsWith('http') 
                          ? NetworkImage(otherAvatar) as ImageProvider
                          : AssetImage(otherAvatar))
                      : null,
                  child: isCustomer || otherAvatar.isEmpty
                      ? Text(
                          otherName.isNotEmpty
                              ? otherName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isCustomer ? Colors.grey[700] : Colors.grey[600],
                          ),
                        )
                      : null,
                ),
                if (isBlocked)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              otherName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isCustomer
                                    ? Colors.grey[700]
                                    : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C5C44),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _getTimeAgo(lastTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation.messages != null &&
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId !=
                              widget.customerId &&
                          conversation.messages!.last.isRead)
                        const Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.blue,
                        ),
                      if (conversation.messages != null &&
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId !=
                              widget.customerId &&
                          !conversation.messages!.last.isRead)
                        const Icon(Icons.done, size: 14, color: Colors.grey),
                      if (conversation.messages != null &&
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId !=
                              widget.customerId)
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isBlocked
                              ? '🔒 User is blocked - Tap to unblock'
                              : lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: isBlocked
                                ? Colors.red
                                : (unreadCount > 0
                                      ? Colors.black87
                                      : Colors.grey[600]),
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  void _showConversationOptions(Conversation conversation) {
    final isBlocked = conversation.isBlocked;

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
                ListTile(
                  leading: Icon(
                    isBlocked ? Icons.block : Icons.block_outlined,
                    color: isBlocked ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    isBlocked ? 'Unblock user' : 'Block user',
                    style: TextStyle(
                      color: isBlocked ? Colors.green : Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isBlocked) {
                      _unblockUser(conversation);
                    } else {
                      _showBlockConfirmation(conversation);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete conversation',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(conversation);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBlockConfirmation(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Block User'),
          content: Text(
            'Are you sure you want to block ${_getOtherUserName(conversation)}?\n\n'
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
                _blockUser(conversation);
              },
              child: const Text('Block', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Conversation'),
          content: Text(
            'Are you sure you want to delete the conversation with ${_getOtherUserName(conversation)}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteConversation(conversation);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

// ─── Search Delegate ─────────────────────────────────────────────────────

class _ConversationSearchDelegate extends SearchDelegate {
  final List<Conversation> conversations;
  final Map<String, Map<String, dynamic>> userCache;
  final String Function(Conversation) getOtherUserName;
  final String Function(Conversation) getOtherUserAvatar;
  final String Function(Conversation) getLastMessage;
  final DateTime Function(Conversation) getLastMessageTime;
  final String customerId;
  final Function(Conversation) onConversationTap;

  _ConversationSearchDelegate({
    required this.conversations,
    required this.userCache,
    required this.getOtherUserName,
    required this.getOtherUserAvatar,
    required this.getLastMessage,
    required this.getLastMessageTime,
    required this.customerId,
    required this.onConversationTap,
  });

  @override
  String get searchFieldLabel => 'Search conversations...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2C5C44),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white70),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.white),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _getFilteredResults(query);
    return _buildResultsList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = _getFilteredResults(query);
    return _buildResultsList(results);
  }

  List<Conversation> _getFilteredResults(String searchQuery) {
    if (searchQuery.isEmpty) {
      return conversations.where((conv) => !conv.isDeleted).toList();
    }

    return conversations.where((conv) {
      if (conv.isDeleted) return false;

      final userData = userCache[conv.otherId];
      final userName = userData?['name']?.toString().toLowerCase() ?? '';
      final userPhone = userData?['phone']?.toString().toLowerCase() ?? '';
      final lastMessage = getLastMessage(conv).toLowerCase();
      final query = searchQuery.toLowerCase();

      return userName.contains(query) ||
          userPhone.contains(query) ||
          lastMessage.contains(query);
    }).toList();
  }

  Widget _buildResultsList(List<Conversation> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              query.isEmpty
                  ? 'Type to search conversations'
                  : 'No conversations found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try searching by name or phone number',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final conversation = results[index];
        final otherName = getOtherUserName(conversation);
        final otherAvatar = getOtherUserAvatar(conversation);
        final lastMessage = getLastMessage(conversation);
        final lastTime = getLastMessageTime(conversation);
        final unreadCount = conversation.unreadCount;
        final isBlocked = conversation.isBlocked;
        final isCustomer = conversation.otherRole == UserRole.customer;

        return GestureDetector(
          onTap: () {
            close(context, null);
            if (isBlocked) {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('User Blocked'),
                    content: Text(
                      '$otherName is blocked.\n\n'
                      'You need to unblock this user to send messages.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onConversationTap(conversation);
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
              return;
            }
            onConversationTap(conversation);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: unreadCount > 0 ? const Color(0xFFE8F0FE) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isCustomer
                          ? Colors.grey[300]
                          : Colors.grey[200],
                      backgroundImage:
                          (!isCustomer &&
                              otherAvatar != null &&
                              otherAvatar.isNotEmpty)
                          ? (otherAvatar.startsWith('http') 
                              ? NetworkImage(otherAvatar) as ImageProvider
                              : AssetImage(otherAvatar))
                          : null,
                      child: isCustomer || otherAvatar.isEmpty
                          ? Text(
                              otherName.isNotEmpty
                                  ? otherName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isCustomer ? Colors.grey[700] : Colors.grey[600],
                              ),
                            )
                          : null,
                    ),
                    if (isBlocked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.block,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  otherName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isCustomer
                                        ? Colors.grey[700]
                                        : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (unreadCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C5C44),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            _getTimeAgo(lastTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (conversation.messages != null &&
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId !=
                                  customerId &&
                              conversation.messages!.last.isRead)
                            const Icon(
                              Icons.done_all,
                              size: 14,
                              color: Colors.blue,
                            ),
                          if (conversation.messages != null &&
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId !=
                                  customerId &&
                              !conversation.messages!.last.isRead)
                            const Icon(
                              Icons.done,
                              size: 14,
                              color: Colors.grey,
                            ),
                          if (conversation.messages != null &&
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId !=
                                  customerId)
                            const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isBlocked
                                  ? '🔒 User is blocked - Tap to unblock'
                                  : lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: isBlocked
                                    ? Colors.red
                                    : (unreadCount > 0
                                          ? Colors.black87
                                          : Colors.grey[600]),
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 1) {
      return '${difference.inDays}d';
    } else if (difference.inDays == 1) {
      return '1d';
    } else if (difference.inHours > 1) {
      return '${difference.inHours}h';
    } else if (difference.inHours == 1) {
      return '1h';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }
}