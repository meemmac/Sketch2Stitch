import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user_role.dart';
import 'Cloudinary_service.dart';

class MessagingService {
  MessagingService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary = CloudinaryService();

  static const String _conversations = 'Conversations';
  static const String _messages = 'Messages';
  static const String _customers = 'Customer';
  static const String _tailors = 'Tailor';
  static const String _retailers = 'Retailer';

  // ─── Conversation Management ──────────────────────────────────────────────

  /// Fetches a specific conversation by ID.
  Future<Conversation?> getConversationByConversationId(String conversationId) async {
    try {
      final doc = await _db.collection(_conversations).doc(conversationId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Conversation.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      debugPrint('Error fetching conversation: $e');
      return null;
    }
  }

  /// Streams all conversations for a specific customer.
  Stream<List<Conversation>> getConversationsByCustomerId(String customerId) {
    return _db
        .collection(_conversations)
        .where('customerId', isEqualTo: customerId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Conversation.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Streams all conversations for a user (Customer, Tailor, or Retailer).
  /// Merges both 'customerId' and 'otherId' streams to ensure all parties see the chat.
  Stream<List<Conversation>> getConversations(String userId) {
    // 🧠 Multi-Role Stream Merger
    // Firestore doesn't support "OR" queries across different fields.
    // We listen to both fields simultaneously and combine them in real-time.
    
    final Stream<QuerySnapshot> asCustomer = _db
        .collection(_conversations)
        .where('customerId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots();


    final Stream<QuerySnapshot> asOther = _db
        .collection(_conversations)
        .where('otherId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots();


    // Use asyncExpand to combine the logic of both streams
    return _db.collection(_conversations).snapshots().asyncMap((_) async {
      // Fetch both sides
      final snaps = await Future.wait([
        _db.collection(_conversations).where('customerId', isEqualTo: userId).where('isDeleted', isEqualTo: false).get(),
        _db.collection(_conversations).where('otherId', isEqualTo: userId).where('isDeleted', isEqualTo: false).get(),
      ]);


      final allDocs = [...snaps[0].docs, ...snaps[1].docs];
      
      // Remove duplicates (if any) and map to models
      final Map<String, Conversation> uniqueConversations = {};
      for (var doc in allDocs) {
        final conv = Conversation.fromJson({...doc.data(), 'id': doc.id});
        uniqueConversations[conv.id] = conv;
      }


      final list = uniqueConversations.values.toList();
      
      // Sort: Newest messages at the top
      list.sort((a, b) {
        final dateA = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });


      return list;
    });
  }

  /// Fetches an existing conversation between two users for a specific order.
  Future<Conversation?> getConversationBetween(String customerId, String otherId, {String? orderId}) async {
    try {
      Query query = _db.collection(_conversations)
          .where('customerId', isEqualTo: customerId)
          .where('otherId', isEqualTo: otherId);
      
      if (orderId != null) {
        query = query.where('orderId', isEqualTo: orderId);
      }

      final snap = await query.limit(1).get();
      if (snap.docs.isEmpty) return null;
      
      return Conversation.fromJson({...snap.docs.first.data() as Map<String, dynamic>, 'id': snap.docs.first.id});
    } catch (e) {
      debugPrint('Error fetching conversation between users: $e');
      return null;
    }
  }

  // ─── Typing Status ────────────────────────────────────────────────────────

  /// Sets the typing status for a user in a conversation.
  Future<void> setTypingStatus(String conversationId, String userId, bool isTyping) async {
    try {
      await _db.collection(_conversations).doc(conversationId).collection('TypingStatus').doc(userId).set({
        'isTyping': isTyping,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting typing status: $e');
    }
  }

  /// Streams the typing status of the other user in a conversation.
  Stream<bool> streamTypingStatus(String conversationId, String otherUserId) {
    return _db
        .collection(_conversations)
        .doc(conversationId)
        .collection('TypingStatus')
        .doc(otherUserId)
        .snapshots()
        .map((snap) => (snap.data()?['isTyping'] as bool?) ?? false);
  }

  /// Creates a new conversation record.
  Future<Conversation> createConversation({
    required String customerId,
    required String otherId,
    required UserRole otherRole,
    required String orderId,
  }) async {
    debugPrint('[MessagingService] 🛠️ Creating new conversation: $customerId <-> $otherId');
    try {
      final now = Timestamp.now();
      final data = {
        'customerId': customerId,
        'otherId': otherId,
        'otherRole': otherRole.name,
        'orderId': orderId,
        'unreadCount': 0,
        'isBlocked': false,
        'isDeleted': false,
        'updatedAt': now,
      };


      final ref = await _db.collection(_conversations).add(data);
      debugPrint('[MessagingService] ✅ Conversation created with ID: ${ref.id}');
      
      return Conversation(
        id: ref.id,
        customerId: customerId,
        otherId: otherId,
        otherRole: otherRole,
        orderId: orderId,
        updatedAt: now.toDate(),
      );
    } catch (e) {
      debugPrint('[MessagingService] ❌ Error creating conversation: $e');
      rethrow;
    }
  }

  /// Alias for [createConversation].
  Future<Conversation> createConversationByCustomerId(
    String customerId,
    String otherId,
    UserRole otherRole,
    String orderId,
  ) => createConversation(
        customerId: customerId,
        otherId: otherId,
        otherRole: otherRole,
        orderId: orderId,
      );

  /// Marks a conversation as read and resets unread count.
  Future<void> markConversationReadByConversationId(String conversationId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({
        'unreadCount': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking conversation read: $e');
    }
  }

  /// Marks all unread messages as read for a specific user in a conversation.
  Future<void> markMessagesRead(String conversationId, String userId) async {
    try {
      final batch = _db.batch();
      final unreadMessages = await _db
          .collection(_messages)
          .where('conversationId', isEqualTo: conversationId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadMessages.docs) {
        if (doc.data()['senderId'] != userId) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }

      batch.update(_db.collection(_conversations).doc(conversationId), {
        'unreadCount': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages read: $e');
    }
  }

  /// Soft deletes a conversation.
  Future<void> deleteConversationByConversationId(String conversationId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  /// Blocks a conversation.
  Future<void> blockConversationByConversationId(String conversationId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({
        'isBlocked': true,
      });
    } catch (e) {
      debugPrint('Error blocking conversation: $e');
    }
  }

  /// Unblocks a conversation.
  Future<void> unblockConversationByConversationId(String conversationId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({
        'isBlocked': false,
      });
    } catch (e) {
      debugPrint('Error unblocking conversation: $e');
    }
  }

  // ─── Message Management ──────────────────────────────────────────────────

  /// Fetches chat history for a specific conversation.
  Stream<List<Message>> getMessagesByConversationId(String conversationId) {
    return _db
        .collection(_messages)
        .where('conversationId', isEqualTo: conversationId)
        // 🧠 Removed orderBy to prevent messages from "vanishing" while server timestamp is null.
        .snapshots()
        .map((snap) {
          final messages = snap.docs
            .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
          
          // Sort in memory instead: Oldest messages at the top.
          messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          return messages;
        });
  }

  /// Fetches paginated messages for a conversation.
  Future<List<Message>> getMessages(String conversationId, {int limit = 20, DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _db
          .collection(_messages)
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snap = await query.get();
      return snap.docs
          .map((doc) => Message.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching paginated messages: $e');
      return [];
    }
  }

  /// Sends a message and updates the conversation timestamp and unread count.
  Future<void> sendMessage(String conversationId, String senderId, Map<String, dynamic> data) async {
    debugPrint('[MessagingService] 📤 Attempting direct send in conv: $conversationId');
    try {
      final msgData = {
        ...data,
        'conversationId': conversationId,
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };


      // 1. Add Message document first
      final docRef = await _db.collection(_messages).add(msgData);
      debugPrint('[MessagingService] 📥 Message ADDED to Firestore with ID: ${docRef.id}');


      // 2. Update Conversation document separately
      await _db.collection(_conversations).doc(conversationId).set({
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
        'isDeleted': false,
      }, SetOptions(merge: true));
      
      debugPrint('[MessagingService] ✅ Conversation metadata UPDATED');
    } catch (e) {
      debugPrint('[MessagingService] ❌ CRITICAL Error: $e');
      rethrow;
    }
  }

  /// Alias for [sendMessage] but takes a [Message] object.
  Future<void> sendMessageByConversationId(String conversationId, Message message) async {
    await sendMessage(conversationId, message.senderId, message.toJson());
  }

  /// Deletes a specific message by ID.
  Future<void> deleteMessageByMessageId(String messageId) async {
    try {
      await _db.collection(_messages).doc(messageId).delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  // ─── Attachments ──────────────────────────────────────────────────────────

  /// Uploads a file to Cloudinary and returns the URL.
  Future<String?> uploadAttachmentFile(File file) async {
    return await _cloudinary.uploadImage(file, folder: 'chat_attachments');
  }

  // ─── User Search ──────────────────────────────────────────────────────────

  /// Fetches basic user info (name, profilePicture) for any role.
  Future<Map<String, dynamic>?> getUserBasicInfo(String userId, UserRole role) async {
    try {
      final collection = role == UserRole.customer 
          ? _customers 
          : (role == UserRole.tailor ? _tailors : _retailers);
      
      final doc = await _db.collection(collection).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      
      final data = doc.data()!;
      return {
        'id': userId,
        'name': data['name'] ?? data['shopName'] ?? 'Unknown',
        'profilePicture': data['profilePicture'],
        'role': role.name,
      };
    } catch (e) {
      debugPrint('Error getting user basic info: $e');
      return null;
    }
  }

  /// Searches for users across Customers, Tailors, and Retailers by name, shopName, or phone.
  Future<List<Map<String, dynamic>>> searchUsersByNameOrPhone(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final List<Map<String, dynamic>> results = [];
      final collections = [_customers, _tailors, _retailers];
      
      for (var col in collections) {
        // 1. Search by 'name' field
        final nameSnap = await _db.collection(col)
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(5)
            .get();
        
        results.addAll(nameSnap.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
          'role': col == _customers ? 'customer' : (col == _tailors ? 'tailor' : 'retailer'),
          'name': doc.data()['name'] ?? doc.data()['shopName'] ?? 'Unknown',
        }));


        // 2. Search by 'shopName' field (Specifically for Retailers)
        if (col == _retailers) {
          final shopSnap = await _db.collection(col)
              .where('shopName', isGreaterThanOrEqualTo: query)
              .where('shopName', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(5)
              .get();
          
          for (var doc in shopSnap.docs) {
            // Avoid adding duplicates if already found by 'name'
            if (!results.any((r) => r['id'] == doc.id)) {
              results.add({
                ...doc.data(),
                'id': doc.id,
                'role': 'retailer',
                'name': doc.data()['shopName'] ?? 'Unknown',
              });
            }
          }
        }


        // 3. Search by 'phone' field
        if (results.length < 10) {
          final phoneSnap = await _db.collection(col)
              .where('phone', isGreaterThanOrEqualTo: query)
              .where('phone', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(5)
              .get();
          
          for (var doc in phoneSnap.docs) {
            if (!results.any((r) => r['id'] == doc.id)) {
              results.add({
                ...doc.data(),
                'id': doc.id,
                'role': col == _customers ? 'customer' : (col == _tailors ? 'tailor' : 'retailer'),
                'name': doc.data()['name'] ?? doc.data()['shopName'] ?? 'Unknown',
              });
            }
          }
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}
