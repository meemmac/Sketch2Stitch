// lib/screens/customer/messaging/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/conversation.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationsScreen extends StatefulWidget {
  final String customerId;

  const ConversationsScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  String _searchQuery = "";
  late TabController _tabController;
  String _selectedTab = "All";

  // User data cache (in production, fetch from API)
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
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
        _applyFilter();
      });
    });
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    // Initialize user cache
    _initUserCache();

    final sampleConversations = [
      Conversation(
        id: 'conv_1',
        customerId: widget.customerId,
        otherId: 't1',
        otherRole: UserRole.tailor,
        orderId: 'ORD-001',
        unreadCount: 1,
        isMuted: false,
        isBlocked: false,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        messages: [
          Message(
            id: 'm1',
            conversationId: 'conv_1',
            senderId: 't1',
            senderRole: UserRole.tailor,
            msgText: 'Your suit is ready for fitting! 🎉',
            sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
            isRead: false,
          ),
          Message(
            id: 'm2',
            conversationId: 'conv_1',
            senderId: widget.customerId,
            senderRole: UserRole.customer,
            msgText: 'Great! I\'ll come tomorrow.',
            sentAt: DateTime.now().subtract(const Duration(hours: 2)),
            isRead: true,
            readAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 55)),
          ),
        ],
      ),
      Conversation(
        id: 'conv_2',
        customerId: widget.customerId,
        otherId: 'r1',
        otherRole: UserRole.retailer,
        orderId: 'ORD-002',
        unreadCount: 0,
        isMuted: true,
        mutedUntil: DateTime.now().add(const Duration(days: 7)),
        isBlocked: false,
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        messages: [
          Message(
            id: 'm3',
            conversationId: 'conv_2',
            senderId: 'r1',
            senderRole: UserRole.retailer,
            msgText: 'Your fabric order has been shipped! 📦',
            sentAt: DateTime.now().subtract(const Duration(days: 1)),
            isRead: true,
            readAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      ),
      Conversation(
        id: 'conv_3',
        customerId: widget.customerId,
        otherId: 't2',
        otherRole: UserRole.tailor,
        orderId: 'ORD-003',
        unreadCount: 2,
        isMuted: false,
        isBlocked: false,
        updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 23)),
        messages: [
          Message(
            id: 'm4',
            conversationId: 'conv_3',
            senderId: widget.customerId,
            senderRole: UserRole.customer,
            msgText: 'I need a custom blazer for my presentation.',
            sentAt: DateTime.now().subtract(const Duration(days: 2)),
            isRead: true,
            readAt: DateTime.now().subtract(const Duration(days: 1, hours: 23)),
          ),
          Message(
            id: 'm5',
            conversationId: 'conv_3',
            senderId: 't2',
            senderRole: UserRole.tailor,
            msgText: 'Sure! Let me know your measurements.',
            sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 23)),
            isRead: false,
          ),
          Message(
            id: 'm6',
            conversationId: 'conv_3',
            senderId: 't2',
            senderRole: UserRole.tailor,
            msgText: 'I can start working on it next week.',
            sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 22)),
            isRead: false,
          ),
        ],
      ),
      Conversation(
        id: 'conv_4',
        customerId: widget.customerId,
        otherId: 'r2',
        otherRole: UserRole.retailer,
        orderId: 'ORD-004',
        unreadCount: 0,
        isMuted: false,
        isBlocked: true,
        updatedAt: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
        messages: [
          Message(
            id: 'm7',
            conversationId: 'conv_4',
            senderId: 'r2',
            senderRole: UserRole.retailer,
            msgText: 'New silk collection just arrived! 🌟',
            sentAt: DateTime.now().subtract(const Duration(days: 3)),
            isRead: true,
            readAt: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
          ),
          Message(
            id: 'm8',
            conversationId: 'conv_4',
            senderId: widget.customerId,
            senderRole: UserRole.customer,
            msgText: 'I\'ll visit your store tomorrow.',
            sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
            isRead: true,
            readAt: DateTime.now().subtract(const Duration(days: 2, hours: 11)),
          ),
        ],
      ),
    ];

    setState(() {
      _conversations = sampleConversations;
      _filteredConversations = sampleConversations;
      _isLoading = false;
    });
  }

  void _initUserCache() {
    _userCache.addAll({
      't1': {
        'name': 'Abdul Karim',
        'avatar': 'assets/images/fab.jpg',
        'role': UserRole.tailor,
        'isOnline': true,
        'lastSeen': null,
      },
      't2': {
        'name': 'Rehana Begum',
        'avatar': 'assets/images/silk.jpg',
        'role': UserRole.tailor,
        'isOnline': false,
        'lastSeen': DateTime.now().subtract(const Duration(hours: 2)),
      },
      'r1': {
        'name': 'Dhaka Fabric House',
        'avatar': 'assets/images/fab.jpg',
        'role': UserRole.retailer,
        'isOnline': false,
        'lastSeen': DateTime.now().subtract(const Duration(hours: 5)),
      },
      'r2': {
        'name': 'Chowdhury Textiles',
        'avatar': 'assets/images/textile.jpg',
        'role': UserRole.retailer,
        'isOnline': true,
        'lastSeen': null,
      },
    });
  }

  void _applyFilter() {
    setState(() {
      List<Conversation> filtered = List.from(_conversations);

      // Exclude deleted conversations
      filtered = filtered.where((conv) => !conv.isDeleted).toList();

      // Search filter
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((conv) {
          final otherName = _getOtherUserName(conv).toLowerCase();
          final lastMessage = _getLastMessage(conv).toLowerCase();
          return otherName.contains(_searchQuery.toLowerCase()) ||
              lastMessage.contains(_searchQuery.toLowerCase());
        }).toList();
      }

      // Tab filter
      switch (_selectedTab) {
        case "Unread":
          filtered = filtered.where((conv) => conv.unreadCount > 0).toList();
          break;
        case "Tailors":
          filtered = filtered.where((conv) =>
              conv.otherRole == UserRole.tailor).toList();
          break;
        case "Retailers":
          filtered = filtered.where((conv) =>
              conv.otherRole == UserRole.retailer).toList();
          break;
        default:
          break;
      }

      _filteredConversations = filtered;
    });
  }

  String _getOtherUserName(Conversation conversation) {
    final userData = _userCache[conversation.otherId];
    if (userData != null) {
      return userData['name'] ?? conversation.otherId;
    }
    return conversation.otherId;
  }

  String _getOtherUserAvatar(Conversation conversation) {
    final userData = _userCache[conversation.otherId];
    if (userData != null) {
      return userData['avatar'] ?? 'assets/images/fab.jpg';
    }
    return 'assets/images/fab.jpg';
  }

  bool _getUserOnlineStatus(Conversation conversation) {
    final userData = _userCache[conversation.otherId];
    if (userData != null) {
      return userData['isOnline'] ?? false;
    }
    return false;
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

  void _markConversationAsRead(String conversationId) {
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        final conversation = _conversations[index];
        
        // Mark all messages from other user as read
        final updatedMessages = conversation.messages?.map((m) {
          if (m.senderId != widget.customerId && !m.isRead) {
            return m.copyWith(
              isRead: true,
              readAt: DateTime.now(),
            );
          }
          return m;
        }).toList();
        
        _conversations[index] = conversation.copyWith(
          messages: updatedMessages,
          unreadCount: 0,
          lastReadAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      _applyFilter();
    });

    // Save to local storage
    _updateConversationReadStatus(conversationId);
  }

  Future<void> _updateConversationReadStatus(String conversationId) async {
    try {
      // TODO: Replace with API call
      // await api.markConversationAsRead(conversationId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_read_$conversationId',
        DateTime.now().toIso8601String(),
      );
      await prefs.setInt('unread_count_$conversationId', 0);
      
    } catch (e) {
      print('Error updating read status: $e');
    }
  }

  void _onConversationRead(String conversationId) {
    _markConversationAsRead(conversationId);
  }

  Future<void> _toggleMute(Conversation conversation) async {
    final isMuted = conversation.isMuted;
    final newMuteStatus = !isMuted;
    
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(
          isMuted: newMuteStatus,
          mutedUntil: newMuteStatus ? DateTime.now().add(const Duration(days: 7)) : null,
          updatedAt: DateTime.now(),
        );
      }
      _applyFilter();
    });

    try {
      // TODO: Replace with API call
      // await api.updateConversation(
      //   conversation.id,
      //   isMuted: newMuteStatus,
      //   mutedUntil: newMuteStatus ? DateTime.now().add(const Duration(days: 7)) : null,
      // );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newMuteStatus 
                ? 'Notifications muted for ${_getOtherUserName(conversation)}' 
                : 'Notifications unmuted for ${_getOtherUserName(conversation)}',
          ),
          backgroundColor: const Color(0xFF2C5C44),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isMuted: isMuted,
          );
        }
        _applyFilter();
      });
    }
  }

  Future<void> _blockUser(Conversation conversation) async {
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

    try {
      // TODO: Replace with API call
      // await api.blockConversation(conversation.id, widget.customerId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getOtherUserName(conversation)} has been blocked'),
          backgroundColor: const Color(0xFF2C5C44),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isBlocked: false,
          );
        }
        _applyFilter();
      });
    }
  }

  Future<void> _unblockUser(Conversation conversation) async {
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

    try {
      // TODO: Replace with API call
      // await api.unblockConversation(conversation.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getOtherUserName(conversation)} has been unblocked'),
          backgroundColor: const Color(0xFF2C5C44),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isBlocked: true,
          );
        }
        _applyFilter();
      });
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(
          isDeleted: true,
          deletedAt: DateTime.now(),
          deletedBy: widget.customerId,
          updatedAt: DateTime.now(),
        );
      }
      _applyFilter();
    });

    try {
      // TODO: Replace with API call
      // await api.deleteConversation(conversation.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Conversation deleted'),
          backgroundColor: const Color(0xFF2C5C44),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isDeleted: false,
            deletedAt: null,
            deletedBy: null,
          );
        }
        _applyFilter();
      });
    }
  }

  void _showNewConversationDialog() {
    final List<Map<String, dynamic>> contacts = [
      {'id': 't3', 'name': 'Fatima Noor', 'role': UserRole.tailor, 'avatar': 'assets/images/lace.jpg'},
      {'id': 't4', 'name': 'Kamal Hossain', 'role': UserRole.tailor, 'avatar': 'assets/images/fab2.jpg'},
      {'id': 'r3', 'name': 'Silk & Lace Emporium', 'role': UserRole.retailer, 'avatar': 'assets/images/silk.jpg'},
      {'id': 'r4', 'name': 'Bengal Cotton Co.', 'role': UserRole.retailer, 'avatar': 'assets/images/fab2.jpg'},
      {'id': 't5', 'name': 'Mohammed Rafiq', 'role': UserRole.tailor, 'avatar': 'assets/images/textile.jpg'},
      {'id': 'r5', 'name': 'Heritage Weaves', 'role': UserRole.retailer, 'avatar': 'assets/images/lace.jpg'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String searchQuery = '';
            
            List filteredContacts = contacts.where((contact) {
              return contact['name'].toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredContacts.isEmpty
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
                                  'No contacts found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = filteredContacts[index];
                              final isTailor = contact['role'] == UserRole.tailor;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: AssetImage(contact['avatar']),
                                  radius: 24,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isTailor ? const Color(0xFF2C5C44) : Colors.blue,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  contact['name'],
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  isTailor ? 'Tailor' : 'Retailer',
                                  style: TextStyle(
                                    color: isTailor ? const Color(0xFF2C5C44) : Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                                onTap: () {
                                  Navigator.pop(context);
                                  final existingConv = _conversations.firstWhere(
                                    (conv) => conv.otherId == contact['id'],
                                    orElse: () => Conversation(
                                      id: 'conv_new_${DateTime.now().millisecondsSinceEpoch}',
                                      customerId: widget.customerId,
                                      otherId: contact['id'],
                                      otherRole: contact['role'],
                                      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                                      messages: [],
                                      unreadCount: 0,
                                      isMuted: false,
                                      isBlocked: false,
                                      updatedAt: DateTime.now(),
                                    ),
                                  );

                                  // Add to cache
                                  _userCache[contact['id']] = {
                                    'name': contact['name'],
                                    'avatar': contact['avatar'],
                                    'role': contact['role'],
                                    'isOnline': false,
                                    'lastSeen': null,
                                  };

                                  if (!_conversations.any((c) => c.id == existingConv.id)) {
                                    setState(() {
                                      _conversations.add(existingConv);
                                      _applyFilter();
                                    });
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        conversationId: existingConv.id,
                                        customerId: widget.customerId,
                                        otherUserId: existingConv.otherId,
                                        otherUserName: contact['name'],
                                        otherUserRole: existingConv.otherRole,
                                        otherUserAvatar: contact['avatar'],
                                        orderId: existingConv.orderId,
                                        onConversationRead: _onConversationRead,
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
          _markConversationAsRead(conversation.id);
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
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
                Tab(text: 'Tailors'),
                Tab(text: 'Retailers'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationDialog,
        backgroundColor: const Color(0xFF2C5C44),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2C5C44),
              ),
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
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showNewConversationDialog,
            icon: const Icon(Icons.chat),
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
          Icon(
            Icons.filter_alt_off,
            size: 80,
            color: Colors.grey[400],
          ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
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
    final isOnline = _getUserOnlineStatus(conversation);
    final unreadCount = conversation.unreadCount;
    final isMuted = conversation.isMuted;
    final isBlocked = conversation.isBlocked;

    return GestureDetector(
      onTap: () {
        // ✅ FIXED: Always open the chat, even if blocked
        // The ChatScreen will handle the blocked state UI
        _markConversationAsRead(conversation.id);
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
                  backgroundColor: Colors.grey[200],
                  backgroundImage: AssetImage(otherAvatar),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
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
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isMuted) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.notifications_off,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                            ],
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation.messages != null && 
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId != widget.customerId &&
                          conversation.messages!.last.isRead)
                        const Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.blue,
                        ),
                      if (conversation.messages != null && 
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId != widget.customerId &&
                          !conversation.messages!.last.isRead)
                        const Icon(
                          Icons.done,
                          size: 14,
                          color: Colors.grey,
                        ),
                      if (conversation.messages != null && 
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId != widget.customerId)
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isBlocked ? '🔒 User is blocked - Tap to unblock' : lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: isBlocked ? Colors.red : (unreadCount > 0 ? Colors.black87 : Colors.grey[600]),
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
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
    final isMuted = conversation.isMuted;

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
                    isMuted ? Icons.notifications : Icons.notifications_off,
                    color: isMuted ? Colors.green : Colors.grey,
                  ),
                  title: Text(isMuted ? 'Unmute notifications' : 'Mute notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleMute(conversation);
                  },
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
    final results = conversations.where((conv) {
      if (conv.isDeleted) return false;
      final otherName = getOtherUserName(conv).toLowerCase();
      final lastMessage = getLastMessage(conv).toLowerCase();
      return otherName.contains(query.toLowerCase()) ||
          lastMessage.contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
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

        return GestureDetector(
          onTap: () {
            close(context, null);
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
                      backgroundColor: Colors.grey[200],
                      backgroundImage: AssetImage(otherAvatar),
                    ),
                    if (userCache[conversation.otherId]?['isOnline'] == true)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 2),
                            ),
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
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (conversation.isMuted) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.notifications_off,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                ],
                                if (unreadCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (conversation.messages != null && 
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId != customerId &&
                              conversation.messages!.last.isRead)
                            const Icon(
                              Icons.done_all,
                              size: 14,
                              color: Colors.blue,
                            ),
                          if (conversation.messages != null && 
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId != customerId &&
                              !conversation.messages!.last.isRead)
                            const Icon(
                              Icons.done,
                              size: 14,
                              color: Colors.grey,
                            ),
                          if (conversation.messages != null && 
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId != customerId)
                            const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              conversation.isBlocked ? '🔒 User is blocked - Tap to unblock' : lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: conversation.isBlocked ? Colors.red : (unreadCount > 0 ? Colors.black87 : Colors.grey[600]),
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
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

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
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