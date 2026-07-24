// lib/screens/customer/messaging/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/conversation.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';

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
  String _selectedTab = "All"; // All, Unread, Tailors, Retailers

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

    final sampleConversations = [
      Conversation(
        id: 'conv_1',
        customerId: widget.customerId,
        otherId: 't1',
        otherRole: UserRole.tailor,
        orderId: 'ORD-001',
        messages: [
          Message(
            id: 'm1',
            conversationId: 'conv_1',
            senderId: 't1',
            senderRole: UserRole.tailor,
            msgText: 'Your suit is ready for fitting! 🎉',
            sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          Message(
            id: 'm2',
            conversationId: 'conv_1',
            senderId: widget.customerId,
            senderRole: UserRole.customer,
            msgText: 'Great! I\'ll come tomorrow.',
            sentAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      ),
      Conversation(
        id: 'conv_2',
        customerId: widget.customerId,
        otherId: 'r1',
        otherRole: UserRole.retailer,
        orderId: 'ORD-002',
        messages: [
          Message(
            id: 'm3',
            conversationId: 'conv_2',
            senderId: 'r1',
            senderRole: UserRole.retailer,
            msgText: 'Your fabric order has been shipped! 📦',
            sentAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      ),
      Conversation(
        id: 'conv_3',
        customerId: widget.customerId,
        otherId: 't2',
        otherRole: UserRole.tailor,
        orderId: 'ORD-003',
        messages: [
          Message(
            id: 'm4',
            conversationId: 'conv_3',
            senderId: widget.customerId,
            senderRole: UserRole.customer,
            msgText: 'I need a custom blazer for my presentation.',
            sentAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          Message(
            id: 'm5',
            conversationId: 'conv_3',
            senderId: 't2',
            senderRole: UserRole.tailor,
            msgText: 'Sure! Let me know your measurements.',
            sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 23)),
          ),
        ],
      ),
      Conversation(
        id: 'conv_4',
        customerId: widget.customerId,
        otherId: 'r2',
        otherRole: UserRole.retailer,
        orderId: 'ORD-004',
        messages: [
          Message(
            id: 'm6',
            conversationId: 'conv_4',
            senderId: 'r2',
            senderRole: UserRole.retailer,
            msgText: 'New silk collection just arrived! 🌟',
            sentAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
          Message(
            id: 'm7',
            conversationId: 'conv_4',
            senderId: widget.customerId,
            senderRole: UserRole.customer,
            msgText: 'I\'ll visit your store tomorrow.',
            sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
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

  void _applyFilter() {
    setState(() {
      List<Conversation> filtered = List.from(_conversations);

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((conv) {
          final otherName = _getOtherUserName(conv).toLowerCase();
          final lastMessage = _getLastMessage(conv).toLowerCase();
          return otherName.contains(_searchQuery.toLowerCase()) ||
              lastMessage.contains(_searchQuery.toLowerCase());
        }).toList();
      }

      // Apply tab filter
      switch (_selectedTab) {
        case "Unread":
          filtered = filtered.where((conv) {
            final unreadCount = conv.messages?.where((m) =>
                m.senderId != widget.customerId).length ?? 0;
            return unreadCount > 0;
          }).toList();
          break;
        case "Tailors":
          filtered = filtered.where((conv) =>
              conv.otherRole == UserRole.tailor).toList();
          break;
        case "Retailers":
          filtered = filtered.where((conv) =>
              conv.otherRole == UserRole.retailer).toList();
          break;
        default: // "All"
          break;
      }

      _filteredConversations = filtered;
    });
  }

  String _getOtherUserName(Conversation conversation) {
    final names = {
      't1': 'Abdul Karim',
      't2': 'Rehana Begum',
      'r1': 'Dhaka Fabric House',
      'r2': 'Chowdhury Textiles',
    };
    return names[conversation.otherId] ?? 'Unknown';
  }

  String _getOtherUserAvatar(Conversation conversation) {
    final avatars = {
      't1': 'assets/images/fab.jpg',
      't2': 'assets/images/silk.jpg',
      'r1': 'assets/images/fab.jpg',
      'r2': 'assets/images/textile.jpg',
    };
    return avatars[conversation.otherId] ?? 'assets/images/fab.jpg';
  }

  String _getLastMessage(Conversation conversation) {
    if (conversation.messages == null || conversation.messages!.isEmpty) {
      return 'No messages yet';
    }
    return conversation.messages!.last.msgText;
  }

  DateTime _getLastMessageTime(Conversation conversation) {
    if (conversation.messages == null || conversation.messages!.isEmpty) {
      return DateTime.now();
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
                                  // Check if conversation already exists
                                  final existingConv = _conversations.firstWhere(
                                    (conv) => conv.otherId == contact['id'],
                                    orElse: () => Conversation(
                                      id: 'conv_new_${DateTime.now().millisecondsSinceEpoch}',
                                      customerId: widget.customerId,
                                      otherId: contact['id'],
                                      otherRole: contact['role'],
                                      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                                      messages: [],
                                    ),
                                  );

                                  if (!_conversations.contains(existingConv)) {
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
        getOtherUserName: _getOtherUserName,
        getLastMessage: _getLastMessage,
        customerId: widget.customerId,
        onConversationTap: (conversation) {
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
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF075E54),
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
            color: const Color(0xFF075E54),
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
        backgroundColor: const Color(0xFF075E54),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF075E54),
              ),
            )
          : _conversations.isEmpty
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
              backgroundColor: const Color(0xFF075E54),
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
    
    final unreadCount = conversation.messages?.where((m) => 
      m.senderId != widget.customerId
    ).length ?? 0;

    return GestureDetector(
      onTap: () {
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
          color: Colors.white,
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
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: AssetImage(otherAvatar),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey,
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // Online status
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
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _getTimeAgo(lastTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation.messages != null && 
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId != widget.customerId)
                        const Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.blue,
                        ),
                      if (conversation.messages != null && 
                          conversation.messages!.isNotEmpty &&
                          conversation.messages!.last.senderId != widget.customerId)
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF075E54),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                  leading: const Icon(Icons.archive, color: Colors.orange),
                  title: const Text('Archive'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Conversation archived'),
                        backgroundColor: Color(0xFF075E54),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off, color: Colors.grey),
                  title: const Text('Mute notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications muted'),
                        backgroundColor: Color(0xFF075E54),
                      ),
                    );
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
                setState(() {
                  _conversations.remove(conversation);
                  _applyFilter();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversation deleted'),
                    backgroundColor: Color(0xFF075E54),
                  ),
                );
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
  final String Function(Conversation) getOtherUserName;
  final String Function(Conversation) getLastMessage;
  final String customerId;
  final Function(Conversation) onConversationTap;

  _ConversationSearchDelegate({
    required this.conversations,
    required this.getOtherUserName,
    required this.getLastMessage,
    required this.customerId,
    required this.onConversationTap,
  });

  @override
  String get searchFieldLabel => 'Search conversations...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF075E54),
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
        final otherAvatar = _getOtherUserAvatar(conversation);
        final lastMessage = getLastMessage(conversation);
        final lastTime = _getLastMessageTime(conversation);
        
        final unreadCount = conversation.messages?.where((m) => 
          m.senderId != customerId
        ).length ?? 0;

        return GestureDetector(
          onTap: () {
            close(context, null);
            onConversationTap(conversation);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
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
                            child: Text(
                              otherName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _getTimeAgo(lastTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (conversation.messages != null && 
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId != customerId)
                            const Icon(
                              Icons.done_all,
                              size: 14,
                              color: Colors.blue,
                            ),
                          if (conversation.messages != null && 
                              conversation.messages!.isNotEmpty &&
                              conversation.messages!.last.senderId != customerId)
                            const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF075E54),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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

  String _getOtherUserAvatar(Conversation conversation) {
    final avatars = {
      't1': 'assets/images/fab.jpg',
      't2': 'assets/images/silk.jpg',
      'r1': 'assets/images/fab.jpg',
      'r2': 'assets/images/textile.jpg',
    };
    return avatars[conversation.otherId] ?? 'assets/images/fab.jpg';
  }

  DateTime _getLastMessageTime(Conversation conversation) {
    if (conversation.messages == null || conversation.messages!.isEmpty) {
      return DateTime.now();
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
}