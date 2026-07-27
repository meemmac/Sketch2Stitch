// lib/screens/customer/messaging/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/conversation.dart';
import 'package:sketch2stitch/models/message.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/customer.dart';

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
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  String _searchQuery = "";
  late TabController _tabController;
  String _selectedTab = "All";

  // User data cache with Tailor and Retailer models
  final Map<String, Map<String, dynamic>> _userCache = {};

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
    _removeNotificationOverlay();
    super.dispose();
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
    
    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _removeNotificationOverlay();
    });
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    _initUserCache();

    // ✅ All conversations (both Tailor/Retailer and Customer)
    final allConversations = [
      // Tailor conversations
      Conversation(
        id: 'conv_1',
        customerId: widget.customerId,
        otherId: 't1',
        otherRole: UserRole.tailor,
        orderId: 'ORD-001',
        unreadCount: 1,
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
      // Retailer conversation
      Conversation(
        id: 'conv_2',
        customerId: widget.customerId,
        otherId: 'r1',
        otherRole: UserRole.retailer,
        orderId: 'ORD-002',
        unreadCount: 0,
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
      // Another Tailor conversation
      Conversation(
        id: 'conv_3',
        customerId: widget.customerId,
        otherId: 't2',
        otherRole: UserRole.tailor,
        orderId: 'ORD-003',
        unreadCount: 2,
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
      // Another Retailer conversation
      Conversation(
        id: 'conv_4',
        customerId: widget.customerId,
        otherId: 'r2',
        otherRole: UserRole.retailer,
        orderId: 'ORD-004',
        unreadCount: 0,
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
      // ✅ Customer to Customer conversation (for Tailor/Retailer view)
      // ✅ Multiple Customer conversations
      Conversation(
        id: 'conv_5',
        customerId: widget.customerId,
        otherId: 'c2',
        otherRole: UserRole.customer,
        orderId: 'ORD-005',
        unreadCount: 1,
        isBlocked: false,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        messages: [
          Message(
            id: 'm9',
            conversationId: 'conv_5',
            senderId: 'c2',
            senderRole: UserRole.customer,
            msgText: 'Hi! I need help with my order.',
            sentAt: DateTime.now().subtract(const Duration(hours: 1)),
            isRead: false,
          ),
        ],
      ),
      Conversation(
        id: 'conv_6',
        customerId: widget.customerId,
        otherId: 'c3',
        otherRole: UserRole.customer,
        orderId: 'ORD-006',
        unreadCount: 0,
        isBlocked: false,
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        messages: [
          Message(
            id: 'm10',
            conversationId: 'conv_6',
            senderId: 'c3',
            senderRole: UserRole.customer,
            msgText: 'Thank you for the amazing service!',
            sentAt: DateTime.now().subtract(const Duration(days: 1)),
            isRead: true,
          ),
        ],
      ),
      Conversation(
        id: 'conv_7',
        customerId: widget.customerId,
        otherId: 'c4',
        otherRole: UserRole.customer,
        orderId: 'ORD-007',
        unreadCount: 2,
        isBlocked: false,
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
        messages: [
          Message(
            id: 'm11',
            conversationId: 'conv_7',
            senderId: 'c4',
            senderRole: UserRole.customer,
            msgText: 'When will my order be delivered?',
            sentAt: DateTime.now().subtract(const Duration(hours: 3)),
            isRead: false,
          ),
          Message(
            id: 'm12',
            conversationId: 'conv_7',
            senderId: 'c4',
            senderRole: UserRole.customer,
            msgText: 'Please let me know.',
            sentAt: DateTime.now().subtract(const Duration(hours: 2)),
            isRead: false,
          ),
        ],
      ),
    ];

    // Filter based on role
    List<Conversation> filteredConversations;
    if (widget.currentUserRole == UserRole.customer) {
      filteredConversations = allConversations.where((conv) =>
      conv.otherRole == UserRole.tailor || conv.otherRole == UserRole.retailer).toList();
    } else {
      // Tailor/Retailer: ONLY Customer
      filteredConversations = allConversations.where((conv) =>
      conv.otherRole == UserRole.customer).toList();
    }

    setState(() {
      _conversations = filteredConversations;
      _filteredConversations = filteredConversations;
      _isLoading = false;
    });
  }
  void _initUserCache() {
    // Tailors
    final tailor1 = Tailor(
      id: 't1',
      name: 'Abdul Karim',
      email: 'abdul@tailor.com',
      phone: '01711111111',
      address: 'Dhaka',
      rating: 4.8,
      profilePicture: 'assets/images/fab.jpg',
    );

    final tailor2 = Tailor(
      id: 't2',
      name: 'Rehana Begum',
      email: 'rehana@tailor.com',
      phone: '01722222222',
      address: 'Dhaka',
      rating: 4.5,
      profilePicture: 'assets/images/silk.jpg',
    );

    // Retailers
    final retailer1 = Retailer(
      id: 'r1',
      shopName: 'Dhaka Fabric House',
      email: 'info@dhakafabric.com',
      phone: '01911111111',
      address: 'Dhaka',
      rating: 4.7,
      profilePicture: 'assets/images/fab.jpg',
    );

    final retailer2 = Retailer(
      id: 'r2',
      shopName: 'Chowdhury Textiles',
      email: 'info@chowdhurytextiles.com',
      phone: '01922222222',
      address: 'Dhaka',
      rating: 4.6,
      profilePicture: 'assets/images/textile.jpg',
    );

    // ✅ Multiple Customers (no profile picture)
    final customer2 = Customer(
      id: 'c2',
      name: 'Fatima Khan',
      email: 'fatima@example.com',
      phone: '01522222222',
      address: 'Dhaka',
    );
    final customer3 = Customer(
      id: 'c3',
      name: 'Aisha Rahman',
      email: 'aisha@example.com',
      phone: '01533333333',
      address: 'Dhaka',
    );
    final customer4 = Customer(
      id: 'c4',
      name: 'Nadia Hasan',
      email: 'nadia@example.com',
      phone: '01544444444',
      address: 'Dhaka',
    );
    final customer5 = Customer(
      id: 'c5',
      name: 'Zara Malik',
      email: 'zara@example.com',
      phone: '01555555555',
      address: 'Dhaka',
    );
    final customer6 = Customer(
      id: 'c6',
      name: 'Mariam Ali',
      email: 'mariam@example.com',
      phone: '01566666666',
      address: 'Dhaka',
    );
    final customer7 = Customer(
      id: 'c7',
      name: 'Hassan Raza',
      email: 'hassan@example.com',
      phone: '01577777777',
      address: 'Dhaka',
    );
    final customer8 = Customer(
      id: 'c8',
      name: 'Sana Khan',
      email: 'sana@example.com',
      phone: '01588888888',
      address: 'Dhaka',
    );

    _userCache.addAll({
      // ... Tailors and Retailers (same as before)
't1': {
  'name': tailor1.name,
  'phone': tailor1.phone,
  'avatar': tailor1.profilePicture ?? 'assets/images/fab.jpg',
  'role': UserRole.tailor,
  'model': tailor1,
  'isAnonymous': false,
},
      't2': {
        'name': tailor2.name,
        'phone': tailor2.phone,
        'avatar': tailor2.profilePicture ?? 'assets/images/silk.jpg',
        'role': UserRole.tailor,
        'model': tailor2,
        'isAnonymous': false,
      },
      'r1': {
        'name': retailer1.shopName,
        'phone': retailer1.phone,
        'avatar': retailer1.profilePicture ?? 'assets/images/fab.jpg',
        'role': UserRole.retailer,
        'model': retailer1,
        'isAnonymous': false,
      },
      'r2': {
        'name': retailer2.shopName,
        'phone': retailer2.phone,
        'avatar': retailer2.profilePicture ?? 'assets/images/textile.jpg',
        'role': UserRole.retailer,
        'model': retailer2,
        'isAnonymous': false,
      },
      // ✅ All Customers
      'c2': {
        'name': customer2.name,
        'phone': customer2.phone,
        'avatar': null,
        'role': UserRole.customer,
        'model': customer2,
        'isAnonymous': false,
      },
      'c3': {
        'name': customer3.name,
        'phone': customer3.phone,
        'avatar': null,
        'role': UserRole.customer,
        'model': customer3,
        'isAnonymous': false,
      },
      'c4': {
        'name': customer4.name,
        'phone': customer4.phone,
        'avatar': null,
        'role': UserRole.customer,
        'model': customer4,
        'isAnonymous': false,
      },
      'c5': {
        'name': customer5.name,
        'phone': customer5.phone,
        'avatar': null,
        'role': UserRole.customer,
        'model': customer5,
        'isAnonymous': false,
      },
      'c6': {
        'name': customer6.name,
        'phone': customer6.phone,
        'avatar': null,
        'role': UserRole.customer,
        'model': customer6,
        'isAnonymous': false,
      },
      'c7': {
        'name': customer7.name,
        'phone': customer7.phone,
        'avatar': null,
        'role': UserRole.customer,
        'model': customer7,
        'isAnonymous': false,
      },
      'c8': {
        'name': customer8.name,
        'phone': customer8.phone,
        'avatar': null,
        'role': UserRole.customer,
        'model': customer8,
        'isAnonymous': false,
      },
    });
  }

  void _applyFilter() {
    setState(() {
      List<Conversation> filtered = List.from(_conversations);

      // Exclude deleted conversations
      filtered = filtered.where((conv) => !conv.isDeleted).toList();
      // Role-based visibility — customers only talk to tailors/retailers,
      // tailors/retailers only talk to customers.
      filtered = filtered.where((conv) {
        if (widget.currentUserRole == UserRole.customer) {
          return conv.otherRole == UserRole.tailor || conv.otherRole == UserRole.retailer;
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
      // For anonymous users, return the phone number
      if (userData['isAnonymous'] == true) {
        return userData['phone'] ?? conversation.otherId;
      }
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

  bool _isAnonymous(Conversation conversation) {
    final userData = _userCache[conversation.otherId];
    return userData?['isAnonymous'] == true;
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

    _updateConversationReadStatus(conversationId);
  }

  Future<void> _updateConversationReadStatus(String conversationId) async {
    try {
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
    _refreshConversationStatus(conversationId);
  }

  Future<void> _refreshConversationStatus(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isBlocked = prefs.getBool('blocked_$conversationId') ?? false;
      final unreadCount = prefs.getInt('unread_count_$conversationId') ?? 0;
      
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            isBlocked: isBlocked,
            unreadCount: unreadCount,
          );
        }
        _applyFilter();
      });
    } catch (e) {
      print('Error refreshing conversation status: $e');
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
      _showTopNotification('${_getOtherUserName(conversation)} has been blocked');
    } catch (e) {
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
      _showTopNotification('${_getOtherUserName(conversation)} has been unblocked');
    } catch (e) {
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
      _showTopNotification('Conversation deleted');
    } catch (e) {
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
    final List<Map<String, dynamic>> tailorRetailerContacts = [
      {
        'id': 't3',
        'name': 'Fatima Noor',
        'phone': '01733333333',
        'role': UserRole.tailor,
        'avatar': 'assets/images/lace.jpg',
        'roleDisplay': 'Tailor',
        'model': Tailor(
          id: 't3',
          name: 'Fatima Noor',
          email: 'fatima@tailor.com',
          phone: '01733333333',
          address: 'Dhaka',
          rating: 4.9,
          profilePicture: 'assets/images/lace.jpg',
        ),
      },
      {
        'id': 't4',
        'name': 'Kamal Hossain',
        'phone': '01744444444',
        'role': UserRole.tailor,
        'avatar': 'assets/images/fab2.jpg',
        'roleDisplay': 'Tailor',
        'model': Tailor(
          id: 't4',
          name: 'Kamal Hossain',
          email: 'kamal@tailor.com',
          phone: '01744444444',
          address: 'Dhaka',
          rating: 4.3,
          profilePicture: 'assets/images/fab2.jpg',
        ),
      },
      {
        'id': 'r3',
        'name': 'Silk & Lace Emporium',
        'phone': '01933333333',
        'role': UserRole.retailer,
        'avatar': 'assets/images/silk.jpg',
        'roleDisplay': 'Retailer',
        'model': Retailer(
          id: 'r3',
          shopName: 'Silk & Lace Emporium',
          email: 'info@silkandlace.com',
          phone: '01933333333',
          address: 'Dhaka',
          rating: 4.8,
          profilePicture: 'assets/images/silk.jpg',
        ),
      },
      {
        'id': 'r4',
        'name': 'Bengal Cotton Co.',
        'phone': '01944444444',
        'role': UserRole.retailer,
        'avatar': 'assets/images/fab2.jpg',
        'roleDisplay': 'Retailer',
        'model': Retailer(
          id: 'r4',
          shopName: 'Bengal Cotton Co.',
          email: 'info@bengalcotton.com',
          phone: '01944444444',
          address: 'Dhaka',
          rating: 4.4,
          profilePicture: 'assets/images/fab2.jpg',
        ),
      },
      // ✅ No anonymous contacts
    ];

    final List<Map<String, dynamic>> customerContacts = [
      {
        'id': 'c2',
        'name': 'Fatima Khan',
        'phone': '01522222222',
        'role': UserRole.customer,
        'avatar': null,
        'roleDisplay': 'Customer',
      },
      {
        'id': 'c3',
        'name': 'Aisha Rahman',
        'phone': '01533333333',
        'role': UserRole.customer,
        'avatar': null,
        'roleDisplay': 'Customer',
      },
      {
        'id': 'c4',
        'name': 'Nadia Hasan',
        'phone': '01544444444',
        'role': UserRole.customer,
        'avatar': null,
        'roleDisplay': 'Customer',
      },
      {
        'id': 'c5',
        'name': 'Zara Malik',
        'phone': '01555555555',
        'role': UserRole.customer,
        'avatar': null,
        'roleDisplay': 'Customer',
      },
      {
        'id': 'c6',
        'name': 'Mariam Ali',
        'phone': '01566666666',
        'role': UserRole.customer,
        'avatar': null,
        'roleDisplay': 'Customer',
      },
      {
        'id': 'c7',
        'name': 'Hassan Raza',
        'phone': '01577777777',
        'role': UserRole.customer,
        'avatar': null,
        'roleDisplay': 'Customer',
      },
      {
        'id': 'c8',
        'name': 'Sana Khan',
        'phone': '01588888888',
        'role': UserRole.customer,
        'avatar': null,
        'roleDisplay': 'Customer',
      },
    ];

    final List<Map<String, dynamic>> contacts =
    widget.currentUserRole == UserRole.customer
        ? tailorRetailerContacts
        : customerContacts;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            List filteredContacts = contacts.where((contact) {
              final name = contact['name'].toLowerCase();
              final phone = contact['phone'].toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || phone.contains(query);
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
                  const SizedBox(height: 8),
                  Text(
                    'Search by name or phone number',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
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
                                });
                              },
                            )
                          : null,
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
                                  searchQuery.isEmpty
                                      ? 'No contacts available'
                                      : 'No contacts found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try a different name or phone number',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = filteredContacts[index];
                              final isTailor = contact['role'] == UserRole.tailor;
                              final isAnonymous = contact['isAnonymous'] == true;
                              
                              // For anonymous users, show the phone number as name
                              String displayName = contact['name'];
                              bool hasAvatar = contact['avatar'] != null && contact['avatar'].toString().isNotEmpty;

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: contact['avatar'] != null ? Colors.grey[200] : Colors.grey[300],
                                  backgroundImage: contact['avatar'] != null
                                      ? AssetImage(contact['avatar'])
                                      : null,
                                  child: contact['avatar'] == null
                                      ? Text(
                                    contact['name'].isNotEmpty ? contact['name'][0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  )
                                      : null,
                                ),

                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isAnonymous ? Colors.grey[700] : Colors.black,
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
                                      contact['phone'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Role badge (Tailor/Retailer) - removed "Unknown" label
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isTailor 
                                            ? Colors.green.shade50 
                                            : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isTailor ? 'Tailor' : 'Retailer',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isTailor ? Colors.green.shade700 : Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                                onTap: () {
                                  Navigator.pop(context);
                                  final contactId = contact['id'];
                                  
                                  final existingConv = _conversations.firstWhere(
                                    (conv) => conv.otherId == contactId,
                                    orElse: () => Conversation(
                                      id: 'conv_new_${DateTime.now().millisecondsSinceEpoch}',
                                      customerId: widget.customerId,
                                      otherId: contactId,
                                      otherRole: contact['role'],
                                      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                                      messages: [],
                                      unreadCount: 0,
                                      isBlocked: false,
                                      updatedAt: DateTime.now(),
                                    ),
                                  );

                                  // For anonymous users, store phone number as name
                                  final userName = isAnonymous ? contact['phone'] : displayName;

                                  _userCache[contactId] = {
                                    'name': userName,
                                    'phone': contact['phone'],
                                    'avatar': contact['avatar'],
                                    'role': contact['role'],
                                    'model': contact['model'],
                                    'isAnonymous': isAnonymous,
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
                                        otherUserName: userName,
                                        otherUserRole: existingConv.otherRole,
                                        otherUserAvatar: contact['avatar'],
                                        orderId: existingConv.orderId,
                                        onConversationRead: _onConversationRead,
                                        isBlocked: existingConv.isBlocked,
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
          if (conversation.isBlocked) {
            _showBlockedDialog(conversation);
            return;
          }
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
              tabs: widget.currentUserRole == UserRole.customer
                  ? const [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
                Tab(text: 'Tailors'),
                Tab(text: 'Retailers'),
              ]
                  : const [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
              ],
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
    final unreadCount = conversation.unreadCount;
    final isBlocked = conversation.isBlocked;
    final isCustomer = conversation.otherRole == UserRole.customer;

    return GestureDetector(
      onTap: () {
        if (isBlocked) {
          _showBlockedDialog(conversation);
          return;
        }
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
                // ✅ For Customer: show first letter, no profile picture
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isCustomer ? Colors.grey[300] : Colors.grey[200],
                  backgroundImage: (!isCustomer && otherAvatar != null && otherAvatar.isNotEmpty)
                      ? AssetImage(otherAvatar)
                      : null,
                  child: isCustomer
                      ? Text(
                    otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
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
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                color: isCustomer ? Colors.grey[700] : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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

  // ✅ Fixed: Properly filter results based on query
  @override
  Widget buildResults(BuildContext context) {
    final results = _getFilteredResults(query);
    return _buildResultsList(results);
  }

  // ✅ Fixed: Suggestions also show filtered results
  @override
  Widget buildSuggestions(BuildContext context) {
    final results = _getFilteredResults(query);
    return _buildResultsList(results);
  }

  // ✅ Helper: Get filtered results based on search query
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

  // ✅ Helper: Build the results list
  Widget _buildResultsList(List<Conversation> results) {
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
              query.isEmpty
                  ? 'Type to search conversations'
                  : 'No conversations found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try searching by name or phone number',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
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
        final isAnonymous = userCache[conversation.otherId]?['isAnonymous'] == true;
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
                    // ✅ For Customer: show first letter, no profile picture
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isCustomer ? Colors.grey[300] : Colors.grey[200],
                      backgroundImage: (!isCustomer && otherAvatar != null && otherAvatar.isNotEmpty)
                          ? AssetImage(otherAvatar)
                          : null,
                      child: isCustomer
                          ? Text(
                        otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
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
                                    fontWeight: isAnonymous
                                        ? FontWeight.normal
                                        : (unreadCount > 0 ? FontWeight.bold : FontWeight.w600),
                                    color: isCustomer ? Colors.grey[700] : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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