// lib/services/messaging_service.dart
import 'dart:async';
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

  /// Streams only the conversations [userId] actually takes part in.
  ///
  /// Firestore has no OR across fields, so this merges two server-side
  /// filtered queries (`customerId == me` and `otherId == me`) instead of
  /// downloading the whole collection and filtering on the client.
  Stream<List<Conversation>> getConversations(String userId) {
    final String cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return Stream.value(const []);

    final asCustomer = _db
        .collection(_conversations)
        .where('customerId', isEqualTo: cleanUserId)
        .snapshots();
    final asOther = _db
        .collection(_conversations)
        .where('otherId', isEqualTo: cleanUserId)
        .snapshots();

    QuerySnapshot<Map<String, dynamic>>? customerSnap;
    QuerySnapshot<Map<String, dynamic>>? otherSnap;
    StreamSubscription? customerSub;
    StreamSubscription? otherSub;

    late final StreamController<List<Conversation>> controller;

    void emit() {
      if (customerSnap == null && otherSnap == null) return;
      // Keyed by doc id so a conversation matching both queries appears once.
      final Map<String, Conversation> merged = {};
      for (final snap in [customerSnap, otherSnap]) {
        if (snap == null) continue;
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;
          // Per-user deletion: hidden only for whoever deleted it.
          final deletedFor = (data['deletedFor'] as List?)
                  ?.map((e) => e.toString().trim())
                  .toList() ??
              const <String>[];
          if (deletedFor.contains(cleanUserId)) continue;
          merged[doc.id] = Conversation.fromJson({...data, 'id': doc.id});
        }
      }
      final results = merged.values.toList()
        ..sort((a, b) {
          final dateA = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
      controller.add(results);
    }

    controller = StreamController<List<Conversation>>(
      onListen: () {
        customerSub = asCustomer.listen((s) {
          customerSnap = s;
          emit();
        }, onError: controller.addError);
        otherSub = asOther.listen((s) {
          otherSnap = s;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await customerSub?.cancel();
        await otherSub?.cancel();
      },
    );

    return controller.stream;
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
      final cleanCustomerId = customerId.trim();
      final cleanOtherId = otherId.trim();

      // NOTE: deliberately not filtered by otherRole. The role stored on the
      // doc is "the other party as seen by whoever started the thread", so it
      // cannot be applied symmetrically to the reverse lookup below — filtering
      // one direction and not the other returned different threads for the same
      // pair depending on who opened the chat.
      Query query = _db.collection(_conversations)
          .where('customerId', isEqualTo: cleanCustomerId)
          .where('otherId', isEqualTo: cleanOtherId);
      if (orderId != null) query = query.where('orderId', isEqualTo: orderId);

      final snap = await query.limit(1).get();
      if (snap.docs.isNotEmpty) {
        return Conversation.fromJson({...snap.docs.first.data() as Map<String, dynamic>, 'id': snap.docs.first.id});
      }

      // Check reverse direction in case otherId initiated as customerId
      Query revQuery = _db.collection(_conversations)
          .where('customerId', isEqualTo: cleanOtherId)
          .where('otherId', isEqualTo: cleanCustomerId);
      if (orderId != null) revQuery = revQuery.where('orderId', isEqualTo: orderId);

      final revSnap = await revQuery.limit(1).get();
      if (revSnap.docs.isNotEmpty) {
        return Conversation.fromJson({...revSnap.docs.first.data() as Map<String, dynamic>, 'id': revSnap.docs.first.id});
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching conversation between users: $e');
      return null;
    }
  }

  // ─── Typing Status ────────────────────────────────────────────────────────

  Future<void> setTypingStatus(String conversationId, String userId, bool isTyping) async {
    if (conversationId.startsWith('TEMP-')) return;
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
    if (conversationId.startsWith('TEMP-')) return Stream.value(false);
    return _db
        .collection(_conversations).doc(conversationId).collection('TypingStatus').doc(otherUserId)
        .snapshots().map((snap) => (snap.data()?['isTyping'] as bool?) ?? false);
  }

  // ─── Creation & Read Logic ────────────────────────────────────────────────

  /// Creates the thread, or returns the existing one for the same pair.
  ///
  /// [customerRole] is the role of the *initiator*. Without it the receiving
  /// side has no way to look the initiator up, because `customerId` is simply
  /// whoever opened the chat first — not necessarily a customer.
  Future<Conversation> createConversation({
    required String customerId,
    required String otherId,
    required UserRole otherRole,
    required String orderId,
    UserRole customerRole = UserRole.customer,
  }) async {
    try {
      // Guard against two devices creating duplicate threads for one pair.
      final existing = await getConversationBetween(customerId, otherId);
      if (existing != null) return existing;

      final now = Timestamp.now();
      final data = {
        'customerId': customerId,
        'otherId': otherId,
        'customerRole': customerRole.name,
        'otherRole': otherRole.name,
        'orderId': orderId,
        'unreadCounts': {
          customerId: 0,
          otherId: 0,
        },
        'isBlocked': false,
        'isDeleted': false,
        'deletedFor': <String>[],
        'updatedAt': now,
      };
      final ref = await _db.collection(_conversations).add(data);
      return Conversation(
        id: ref.id,
        customerId: customerId,
        otherId: otherId,
        customerRole: customerRole,
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
    if (conversationId.startsWith('TEMP-')) return;
    try {
      final cleanUserId = userId.trim();
      final conversationRef = _db.collection(_conversations).doc(conversationId);

      final convDoc = await conversationRef.get();
      if (!convDoc.exists) return;
      final convData = convDoc.data() ?? {};

      // Only a participant may clear this thread's unread state.
      final cId = (convData['customerId'] ?? '').toString().trim();
      final oId = (convData['otherId'] ?? '').toString().trim();
      if (cleanUserId != cId && cleanUserId != oId) return;

      final lastSenderId = (convData['lastSenderId'] ?? '').toString().trim();

      final unreadQuery = await _db.collection(_messages)
          .where('conversationId', isEqualTo: conversationId)
          .where('isRead', isEqualTo: false)
          .get();

      // Only mark messages RECEIVED by the current user.
      final toMark = unreadQuery.docs.where((doc) =>
          (doc.data()['senderId'] ?? '').toString().trim() != cleanUserId).toList();

      // Firestore caps a batch at 500 writes — chunk so a long unread backlog
      // does not silently fail to commit.
      const int chunkSize = 400;
      for (var i = 0; i < toMark.length; i += chunkSize) {
        final batch = _db.batch();
        for (final doc in toMark.skip(i).take(chunkSize)) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // Dotted field path so a concurrent increment for the *other* user is
      // not clobbered by writing back a stale copy of the whole map.
      final Map<String, dynamic> updates = {
        'unreadCounts.$cleanUserId': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
      };
      if (lastSenderId != cleanUserId) {
        updates['lastMessageRead'] = true;
      }
      await conversationRef.update(updates);

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

  /// Hides the conversation for [userId] only. Previously this set a shared
  /// `isDeleted` flag, which removed the thread from the other participant's
  /// inbox as well.
  Future<void> deleteConversationByConversationId(String conversationId, String userId) async {
    try {
      await _db.collection(_conversations).doc(conversationId).update({
        'deletedFor': FieldValue.arrayUnion([userId.trim()]),
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': userId.trim(),
      });
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  // ─── Message Management ──────────────────────────────────────────────────

  Stream<List<Message>> getMessagesByConversationId(String conversationId) {
    return _db.collection(_messages).where('conversationId', isEqualTo: conversationId)
        .snapshots().map((snap) {
          final messages = snap.docs.map((doc) => Message.fromJson({...doc.data(), 'id': doc.id})).toList();
          messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          return messages;
        });
  }

  /// Newest message of [conversationId], as an inbox preview.
  ///
  /// Threads written before `lastMessage` was denormalized onto the
  /// conversation carry no preview, so the inbox showed them as
  /// "No messages yet" even when the chat was full of messages. The inbox
  /// falls back to this for those threads.
  Future<Map<String, String>?> getLastMessagePreview(String conversationId) async {
    if (conversationId.startsWith('TEMP-')) return null;
    try {
      final snap = await _db.collection(_messages)
          .where('conversationId', isEqualTo: conversationId)
          .get();

      Message? newest;
      for (final doc in snap.docs) {
        final msg = Message.fromJson({...doc.data(), 'id': doc.id});
        if (newest == null || msg.sentAt.isAfter(newest.sentAt)) newest = msg;
      }
      if (newest == null) return null;

      final String text = newest.msgText.trim();
      final bool hasAttachment = (newest.attachment ?? '').isNotEmpty;
      return {
        'lastMessage': hasAttachment
            ? (text.isNotEmpty ? '\u{1F4F7} $text' : '\u{1F4F7} Photo')
            : text,
        'lastSenderId': newest.senderId.trim(),
      };
    } catch (e) {
      debugPrint('Error loading last message preview: $e');
      return null;
    }
  }

  /// Sends a message and updates the conversation metadata atomically.
  Future<void> sendMessage(String conversationId, String senderId, Map<String, dynamic> data) async {
    final cleanSenderId = senderId.trim();
    try {
      final convRef = _db.collection(_conversations).doc(conversationId);

      // Verify the thread exists BEFORE writing the message — otherwise a bad
      // conversationId leaves an orphaned message that no inbox ever shows.
      final convDoc = await convRef.get();
      if (!convDoc.exists) {
        throw Exception('Conversation "$conversationId" does not exist');
      }

      final convData = convDoc.data()!;
      final String cId = (convData['customerId'] ?? '').toString().trim();
      final String oId = (convData['otherId'] ?? '').toString().trim();
      if (cleanSenderId != cId && cleanSenderId != oId) {
        throw Exception('You are not a participant in this conversation');
      }
      final String receiverId = (cId == cleanSenderId) ? oId : cId;

      String lastMsgPreview = '';
      if (data['attachment'] != null) {
        final caption = (data['msgText'] ?? '').toString().trim();
        lastMsgPreview = caption.isNotEmpty ? '📷 $caption' : '📷 Photo';
      } else {
        lastMsgPreview = (data['msgText'] ?? '').toString().trim();
      }

      // Message + conversation metadata commit together, so a failure can
      // never leave one written without the other.
      final batch = _db.batch();

      batch.set(_db.collection(_messages).doc(), {
        ...data,
        'conversationId': conversationId,
        'senderId': cleanSenderId,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Dotted field paths + increment: concurrent sends can no longer lose
      // each other's unread bump the way a read-modify-write of the whole map did.
      batch.update(convRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.$receiverId': FieldValue.increment(1),
        'unreadCounts.$cleanSenderId': 0,
        'lastMessage': lastMsgPreview,
        'lastSenderId': cleanSenderId,
        'lastMessageRead': false,
        'isDeleted': false,
        // A new message brings the thread back for anyone who had cleared it.
        'deletedFor': FieldValue.arrayRemove([cId, oId]),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('[MessagingService] ❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Deletes a message and, when it was the newest one, refreshes the
  /// conversation preview so the inbox stops showing deleted text.
  Future<void> deleteMessageByMessageId(String messageId, {String? conversationId}) async {
    try {
      await _db.collection(_messages).doc(messageId).delete();
      if (conversationId == null || conversationId.startsWith('TEMP-')) return;

      final remaining = await _db.collection(_messages)
          .where('conversationId', isEqualTo: conversationId)
          .get();

      Message? newest;
      for (final doc in remaining.docs) {
        final msg = Message.fromJson({...doc.data(), 'id': doc.id});
        if (newest == null || msg.sentAt.isAfter(newest.sentAt)) newest = msg;
      }

      String preview = '';
      if (newest != null) {
        final hasAttachment = (newest.attachment ?? '').isNotEmpty;
        final text = newest.msgText.trim();
        preview = hasAttachment
            ? (text.isNotEmpty ? '📷 $text' : '📷 Photo')
            : text;
      }

      await _db.collection(_conversations).doc(conversationId).update({
        'lastMessage': preview,
        'lastSenderId': newest?.senderId ?? '',
      });
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
      // Profiles are saved with `profilePicture: ''` when no photo was picked,
      // and an empty string is not a usable image URL — normalise it to null so
      // callers fall back to the initial avatar.
      final String name = (data['name'] ?? '').toString().trim();
      final String shopName = (data['shopName'] ?? '').toString().trim();
      final String picture = (data['profilePicture'] ?? '').toString().trim();
      return {
        'id': userId,
        'name': name.isNotEmpty ? name : (shopName.isNotEmpty ? shopName : 'Unknown'),
        'profilePicture': picture.startsWith('http') ? picture : null,
        'role': role.name,
      };
    } catch (e) {
      debugPrint('Error getting user basic info: $e');
      return null;
    }
  }

  /// Searches all three user collections. An empty [query] lists everyone —
  /// the "New Conversation" sheet opens with no text typed, and returning an
  /// empty list there showed "No users found in database" every time.
  Future<List<Map<String, dynamic>>> searchUsersByNameOrPhone(String query) async {
    try {
      final List<Map<String, dynamic>> results = [];
      final collections = ['Customer', 'Tailor', 'Retailer'];
      final lowercaseQuery = query.toLowerCase();
      for (var col in collections) {
        try {
          // Firestore cannot do substring matching, so this still scans — the
          // cap keeps a keystroke from pulling an unbounded number of docs.
          final snap = await _db.collection(col).limit(200).get();
          for (var doc in snap.docs) {
            final data = doc.data();
            final role = col == 'Customer' ? 'customer' : (col == 'Tailor' ? 'tailor' : 'retailer');
            final String rawName = (data['name'] ?? '').toString();
            final String rawShopName = (data['shopName'] ?? '').toString();
            final String rawPhone = (data['phone'] ?? '').toString();
            final bool matches = lowercaseQuery.isEmpty ||
                rawName.toLowerCase().contains(lowercaseQuery) ||
                rawShopName.toLowerCase().contains(lowercaseQuery) ||
                rawPhone.contains(query);
            if (matches) {
              if (!results.any((r) => r['id'] == doc.id && r['role'] == role)) {
                final String picture = (data['profilePicture'] ?? '').toString().trim();
                results.add({'id': doc.id, 'name': rawShopName.isNotEmpty ? rawShopName : (rawName.isNotEmpty ? rawName : 'Unknown'), 'profilePicture': picture.startsWith('http') ? picture : null, 'phone': rawPhone, 'role': role});
              }
            }
          }
        } catch (innerError) { debugPrint('Skip bad record in $col: $innerError'); }
      }
      return results;
    } catch (e) { debugPrint('Error searching users: $e'); return []; }
  }
}

