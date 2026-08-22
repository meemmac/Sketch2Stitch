// lib/services/messaging_service.dart
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

  /// Streams all conversations for a user.
  /// Handles both 'customerId' and 'otherId' fields to ensure all roles see their chats.
  Stream<List<Conversation>> getConversations(String userId) {
    final customerStream = _db
        .collection(_conversations)
        .where('customerId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots();

    return customerStream.asyncMap((customerSnap) async {
      final otherSnap = await _db
          .collection(_conversations)
          .where('otherId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .get();

      final allDocs = [...customerSnap.docs, ...otherSnap.docs];
      
      final conversations = allDocs.map((doc) {
        return Conversation.fromJson({...doc.data(), 'id': doc.id});
      }).toList();

      // Sort by updatedAt descending
      conversations.sort((a, b) {
        final dateA = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      return conversations;
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
      return Conversation(
        id: ref.id,
        customerId: customerId,
        otherId: otherId,
        otherRole: otherRole,
        orderId: orderId,
        updatedAt: now.toDate(),
      );
    } catch (e) {
      debugPrint('Error creating conversation: $e');
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
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
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
    try {
      final batch = _db.batch();
      final msgRef = _db.collection(_messages).doc();
      
      final msgData = {
        ...data,
        'conversationId': conversationId,
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      batch.set(msgRef, msgData);
      batch.update(_db.collection(_conversations).doc(conversationId), {
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error sending message: $e');
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

  /// Searches for users across Customers, Tailors, and Retailers by name or phone.
  Future<List<Map<String, dynamic>>> searchUsersByNameOrPhone(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final List<Map<String, dynamic>> results = [];
      
      final collections = [_customers, _tailors, _retailers];
      
      for (var col in collections) {
        // Search by name
        final nameSnap = await _db.collection(col)
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(5)
            .get();
        
        results.addAll(nameSnap.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
          'role': col == _customers ? 'customer' : (col == _tailors ? 'tailor' : 'retailer')
        }));

        // Search by phone
        if (results.length < 10) {
          final phoneSnap = await _db.collection(col)
              .where('phone', isGreaterThanOrEqualTo: query)
              .where('phone', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(5)
              .get();
          
          results.addAll(phoneSnap.docs.map((doc) => {
            ...doc.data(),
            'id': doc.id,
            'role': col == _customers ? 'customer' : (col == _tailors ? 'tailor' : 'retailer')
          }));
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  /// Get user profile by ID and role
  Future<Map<String, dynamic>?> getUserProfile(String userId, UserRole role) async {
    try {
      final collection = _getCollectionForRole(role);
      final doc = await _db.collection(collection).doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Get collection name for role
  String _getCollectionForRole(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return _customers;
      case UserRole.tailor:
        return _tailors;
      case UserRole.retailer:
        return _retailers;
    }
  }
}