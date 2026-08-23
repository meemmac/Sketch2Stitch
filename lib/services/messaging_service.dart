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

  // ─── Conversation Management ──────────────────────────────────────────────

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

  Stream<List<Conversation>> getConversations(String userId) {
    final String cleanUserId = userId.trim();
    return _db
        .collection(_conversations)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final List<Conversation> results = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final String cId = (data['customerId'] ?? '').toString().trim();
        final String oId = (data['otherId'] ?? '').toString().trim();
        if (cId == cleanUserId || oId == cleanUserId) {
          results.add(Conversation.fromJson({...data, 'id': doc.id}));
        }
      }
      results.sort((a, b) {
        final dateA = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      return results;
    });
  }

  Stream<Conversation?> streamConversation(String conversationId) {
    if (conversationId.startsWith('TEMP-')) return Stream.value(null);
    return _db
        .collection(_conversations)
        .doc(conversationId)
        .snapshots()
        .map((snap) => snap.exists ? Conversation.fromJson({...snap.data()!, 'id': snap.id}) : null);
  }

  Future<Conversation?> getConversationBetween(String customerId, String otherId, {UserRole? otherRole, String? orderId}) async {
    try {
      Query query = _db.collection(_conversations)
          .where('customerId', isEqualTo: customerId)
          .where('otherId', isEqualTo: otherId);
      if (otherRole != null) query = query.where('otherRole', isEqualTo: otherRole.name);
      if (orderId != null) query = query.where('orderId', isEqualTo: orderId);

      final snap = await query.limit(1).get();
      if (snap.docs.isEmpty) return null;
      return Conversation.fromJson({...snap.docs.first.data() as Map<String, dynamic>, 'id': snap.docs.first.id});
    } catch (e) {
      debugPrint('Error fetching conversation between users: $e');
      return null;
    }
  }

  // ─── Typing Status ────────────────────────────────────────────────────────

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

  Stream<bool> streamTypingStatus(String conversationId, String otherUserId) {
    return _db
        .collection(_conversations).doc(conversationId).collection('TypingStatus').doc(otherUserId)
        .snapshots().map((snap) => (snap.data()?['isTyping'] as bool?) ?? false);
  }

  // ─── Creation & Read Logic ────────────────────────────────────────────────

  Future<Conversation> createConversation({
    required String customerId, required String otherId, required UserRole otherRole, required String orderId,
  }) async {
    try {
      final now = Timestamp.now();
      final data = {
        'customerId': customerId, 
        'otherId': otherId, 
        'otherRole': otherRole.name,
        'orderId': orderId, 
        'unreadCounts': {
          customerId: 0,
          otherId: 0,
        },
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
        unreadCounts: {customerId: 0, otherId: 0},
      );
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      rethrow;
    }
  }

  /// Marks a conversation as read and resets unread count for [userId].
  Future<void> markConversationReadByConversationId(String conversationId, String userId) async {
    await markMessagesRead(conversationId, userId);
  }

  /// Marks all unread messages received by [userId] as read.
  /// Also resets only that user's unread counter.
  Future<void> markMessagesRead(String conversationId, String userId) async {
    try {
      final cleanUserId = userId.trim();
      final conversationRef = _db.collection(_conversations).doc(conversationId);

      final unreadQuery = await _db.collection(_messages)
          .where('conversationId', isEqualTo: conversationId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();

      for (final doc in unreadQuery.docs) {
        final senderId = (doc.data()['senderId'] ?? '').toString().trim();
        // Only mark messages RECEIVED by the current user.
        if (senderId != cleanUserId) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Reset only this user's unread count in the Map.
      batch.update(conversationRef, {
        'unreadCounts.$cleanUserId': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
        'lastMessageRead': true, 
      });

      await batch.commit();
      debugPrint('[MessagingService] ✅ Messages marked read for $cleanUserId');
    } catch (e) {
      debugPrint('[MessagingService] ❌ Error marking messages read: $e');
    }
  }

  // ─── Blocking & Deletion ──────────────────────────────────────────────────

  Future<void> blockConversationByConversationId(String conversationId, String userId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({
        'isBlocked': true, 
        'blockedBy': userId,
      });
    } catch (e) {
      debugPrint('Error blocking conversation: $e');
    }
  }

  Future<void> unblockConversationByConversationId(String conversationId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({
        'isBlocked': false, 
        'blockedBy': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error unblocking conversation: $e');
    }
  }

  Future<void> deleteConversationByConversationId(String conversationId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({'isDeleted': true, 'deletedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  // ─── Message Management ──────────────────────────────────────────────────

  Stream<Message?> getLatestMessage(String conversationId) {
    return _db.collection(_messages)
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('sentAt', descending: true).limit(1)
        .snapshots().map((snap) => snap.docs.isNotEmpty 
            ? Message.fromJson({...snap.docs.first.data(), 'id': snap.docs.first.id}) : null);
  }

  Stream<List<Message>> getMessagesByConversationId(String conversationId) {
    return _db.collection(_messages).where('conversationId', isEqualTo: conversationId)
        .snapshots().map((snap) {
          final messages = snap.docs.map((doc) => Message.fromJson({...doc.data(), 'id': doc.id})).toList();
          messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          return messages;
        });
  }

  /// Sends a message and updates the conversation metadata atomically.
  Future<void> sendMessage(String conversationId, String senderId, Map<String, dynamic> data) async {
    final cleanSenderId = senderId.trim();
    try {
      final msgData = {
        ...data, 
        'conversationId': conversationId, 
        'senderId': cleanSenderId, 
        'sentAt': FieldValue.serverTimestamp(), 
        'isRead': false,
      };

      // 1. Add Message document
      await _db.collection(_messages).add(msgData);

      // 🛡️ Find the receiver to increment their specific unread count
      final convDoc = await _db.collection(_conversations).doc(conversationId).get();
      if (!convDoc.exists) return;
      
      final convData = convDoc.data()!;
      final String cId = (convData['customerId'] ?? '').toString().trim();
      final String oId = (convData['otherId'] ?? '').toString().trim();
      final String receiverId = (cId == cleanSenderId) ? oId : cId;

      // 2. Update Conversation metadata
      await _db.collection(_conversations).doc(conversationId).set({
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.$receiverId': FieldValue.increment(1),
        'lastMessage': data['msgText'] ?? (data['attachment'] != null ? '📷 Photo' : ''),
        'lastSenderId': cleanSenderId,
        'lastMessageRead': false, 
        'isDeleted': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[MessagingService] ❌ Error sending message: $e');
      rethrow;
    }
  }

  Future<void> deleteMessageByMessageId(String messageId) async {
    try {
      await _db.collection(_messages).doc(messageId).delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  Future<String?> uploadAttachmentFile(File file) async => await _cloudinary.uploadImage(file, folder: 'chat_attachments');

  // ─── User Search ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserBasicInfo(String userId, UserRole role) async {
    try {
      final collection = role == UserRole.customer ? 'Customer' : (role == UserRole.tailor ? 'Tailor' : 'Retailer');
      final doc = await _db.collection(collection).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      return {'id': userId, 'name': data['name'] ?? data['shopName'] ?? 'Unknown', 'profilePicture': data['profilePicture'], 'role': role.name};
    } catch (e) {
      debugPrint('Error getting user basic info: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsersByNameOrPhone(String query) async {
    if (query.isEmpty) return [];
    try {
      final List<Map<String, dynamic>> results = [];
      final collections = ['Customer', 'Tailor', 'Retailer'];
      final lowercaseQuery = query.toLowerCase();
      for (var col in collections) {
        try {
          final snap = await _db.collection(col).get();
          for (var doc in snap.docs) {
            final data = doc.data();
            final role = col == 'Customer' ? 'customer' : (col == 'Tailor' ? 'tailor' : 'retailer');
            final String rawName = (data['name'] ?? '').toString();
            final String rawShopName = (data['shopName'] ?? '').toString();
            final String rawPhone = (data['phone'] ?? '').toString();
            if (rawName.toLowerCase().contains(lowercaseQuery) || rawShopName.toLowerCase().contains(lowercaseQuery) || rawPhone.contains(query)) {
              if (!results.any((r) => r['id'] == doc.id && r['role'] == role)) {
                results.add({'id': doc.id, 'name': rawShopName.isNotEmpty ? rawShopName : (rawName.isNotEmpty ? rawName : 'Unknown'), 'profilePicture': data['profilePicture']?.toString(), 'phone': rawPhone, 'role': role});
              }
            }
          }
        } catch (innerError) { debugPrint('Skip bad record in $col: $innerError'); }
      }
      return results;
    } catch (e) { debugPrint('Error searching users: $e'); return []; }
  }
}
