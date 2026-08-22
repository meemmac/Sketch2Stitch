import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portfolio.dart';
import '../models/review.dart';

/// Thrown by [PortfolioService] with a user-friendly message so callers
/// can surface `e.message` directly without knowing Firestore error codes.
class PortfolioServiceException implements Exception {
  const PortfolioServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Paginated result returned by [PortfolioService.getTailorPortfolio] and
/// [PortfolioService.getTailorReviews].
class PaginatedResult<T> {
  /// The items on this page.
  final List<T> items;

  /// Snapshot of the last document on this page — pass to the next call as
  /// the `page` cursor to fetch the following page. `null` when there are no
  /// more pages.
  final DocumentSnapshot? nextPageCursor;

  /// Whether more pages are available after this one.
  bool get hasMore => nextPageCursor != null;

  const PaginatedResult({required this.items, this.nextPageCursor});
}

/// Wraps all Firestore operations for the Portfolio & Reviews features.
///
/// Collections touched:
///   - `Portfolio` — tailor portfolio items.
///   - `Reviews`   — tailor reviews and rating aggregation.
class PortfolioService {
  PortfolioService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _portfolio = 'Portfolio';
  static const _reviews = 'Reviews';

  /// Default page size used when the caller does not override it.
  static const int defaultPageSize = 10;

  // ── getTailorPortfolio ─────────────────────────────────────────────────────

  /// Returns a paginated list of [Portfolio] items for [tailorId].
  ///
  /// Supports both manual IDs (like 'tailor3') and auto-generated Firestore IDs.
  ///
  /// Pass `null` as [page] for the first page, or the [PaginatedResult.nextPageCursor]
  /// from the previous call to fetch the next page.
  Future<PaginatedResult<Portfolio>> getTailorPortfolio(
    String tailorId, {
    DocumentSnapshot? page,
    int pageSize = defaultPageSize,
  }) async {
    try {
      
      // Query by tailorId - supports both manual and auto-generated IDs
      var query = _db
          .collection(_portfolio)
          .where('tailorId', isEqualTo: tailorId)
          .limit(pageSize);

      if (page != null) {
        query = query.startAfterDocument(page);
      }

      final snap = await query.get();
      

      if (snap.docs.isEmpty) {
        // Try to find portfolio by tailor name if ID didn't work
        final portfolioItems = await _findPortfolioByTailorName(tailorId);
        if (portfolioItems.isNotEmpty) {
          return PaginatedResult(items: portfolioItems, nextPageCursor: null);
        }
        return PaginatedResult(items: [], nextPageCursor: null);
      }

      final items = snap.docs
          .map((d) {
            final data = d.data();
            return Portfolio.fromJson({...data, 'id': d.id});
          })
          .toList();

      final cursor = snap.docs.length == pageSize ? snap.docs.last : null;

      return PaginatedResult(items: items, nextPageCursor: cursor);
    } on FirebaseException catch (e) {
      throw PortfolioServiceException(
        'Failed to fetch portfolio: ${e.message ?? e.code}',
      );
    } catch (e) {
      throw PortfolioServiceException(
        'Failed to fetch portfolio: $e',
      );
    }
  }

  /// Helper method to find portfolio by tailor name when ID doesn't match
  Future<List<Portfolio>> _findPortfolioByTailorName(String tailorId) async {
    try {
      // First, get the tailor document to find the name
      final tailorDoc = await _db.collection('Tailor').doc(tailorId).get();
      if (!tailorDoc.exists) {
        return [];
      }

      final tailorData = tailorDoc.data();
      final tailorName = tailorData?['name'] as String?;
      
      if (tailorName == null || tailorName.isEmpty) {
        return [];
      }


      // Get all portfolio items
      final allPortfolio = await _db.collection(_portfolio).get();
      
      // Filter by tailor name (checking if name is in the document or through tailorId reference)
      final List<Portfolio> matchingItems = [];
      
      for (final doc in allPortfolio.docs) {
        final data = doc.data();
        final portfolioTailorId = data['tailorId'] as String?;
        
        if (portfolioTailorId != null) {
          // Check if this portfolio belongs to the tailor by getting the tailor document
          final tailorDocForPortfolio = await _db.collection('Tailor').doc(portfolioTailorId).get();
          if (tailorDocForPortfolio.exists) {
            final tailorDataForPortfolio = tailorDocForPortfolio.data();
            final name = tailorDataForPortfolio?['name'] as String?;
            if (name == tailorName) {
              matchingItems.add(Portfolio.fromJson({...data, 'id': doc.id}));
            }
          }
        }
      }
      
      return matchingItems;
    } catch (e) {
      return [];
    }
  }

  // ── addPortfolioItem ───────────────────────────────────────────────────────

  /// Creates a new portfolio item for [tailorId] with the given [image] URL
  /// and optional [description].
  ///
  /// Returns the saved [Portfolio] document (including the generated id).
  Future<Portfolio> addPortfolioItem(
    String tailorId,
    String image, {
    String? description,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tailorId': tailorId,
        'image': image,
        if (description != null) 'description': description,
      };

      final ref = await _db.collection(_portfolio).add(payload);
      final snap = await ref.get();

      return Portfolio.fromJson({...snap.data()!, 'id': snap.id});
    } on FirebaseException catch (e) {
      throw PortfolioServiceException(
        'Failed to add portfolio item: ${e.message ?? e.code}',
      );
    }
  }

  // ── updatePortfolioItem ────────────────────────────────────────────────────

  /// Merges [data] into the existing `Portfolio` document identified by
  /// [portfolioId]. Only the supplied fields are overwritten.
  ///
  /// Allowed keys: `image`, `description`.
  ///
  /// Returns the updated [Portfolio].
  Future<Portfolio> updatePortfolioItem(
    String portfolioId,
    Map<String, dynamic> data,
  ) async {
    try {
      final ref = _db.collection(_portfolio).doc(portfolioId);
      await ref.update(data);
      final snap = await ref.get();

      if (!snap.exists) {
        throw const PortfolioServiceException(
          'Portfolio item not found after update.',
        );
      }

      return Portfolio.fromJson({...snap.data()!, 'id': snap.id});
    } on PortfolioServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw PortfolioServiceException(
        'Failed to update portfolio item: ${e.message ?? e.code}',
      );
    }
  }

  // ── deletePortfolioItem ────────────────────────────────────────────────────

  /// Permanently deletes the `Portfolio` document with [portfolioId].
  Future<void> deletePortfolioItem(String portfolioId) async {
    try {
      await _db.collection(_portfolio).doc(portfolioId).delete();
    } on FirebaseException catch (e) {
      throw PortfolioServiceException(
        'Failed to delete portfolio item: ${e.message ?? e.code}',
      );
    }
  }

  // ── getTailorReviews ───────────────────────────────────────────────────────

  /// Returns a paginated list of [Review]s for [tailorId], ordered by
  /// `createdAt` descending (most recent first).
  ///
  /// Pass `null` as [page] for the first page, or the
  /// [PaginatedResult.nextPageCursor] from the previous call to continue.
  ///
  /// Filters on `targetId == tailorId` and `targetRole == 'tailor'`.
  Future<PaginatedResult<Review>> getTailorReviews(
    String tailorId, {
    DocumentSnapshot? page,
    int pageSize = defaultPageSize,
  }) async {
    try {
      var query = _db
          .collection(_reviews)
          .where('targetId', isEqualTo: tailorId)
          .where('targetRole', isEqualTo: ReviewTargetRole.tailor.name)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (page != null) {
        query = query.startAfterDocument(page);
      }

      final snap = await query.get();

      final items = snap.docs.map((d) {
        final data = d.data();
        // createdAt stored as Timestamp in Firestore — normalise to ISO string.
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] =
              (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return Review.fromJson({...data, 'id': d.id});
      }).toList();

      final cursor = snap.docs.length == pageSize ? snap.docs.last : null;

      return PaginatedResult(items: items, nextPageCursor: cursor);
    } on FirebaseException catch (e) {
      throw PortfolioServiceException(
        'Failed to fetch tailor reviews: ${e.message ?? e.code}',
      );
    }
  }

  // ── getTailorAverageRating ─────────────────────────────────────────────────

  /// Computes the average `rating` across all reviews for [tailorId].
  ///
  /// Returns `null` when the tailor has no reviews yet.
  ///
  /// Note: this performs a full collection-group read — consider caching the
  /// result or storing a denormalised `rating` field on the `Tailor` document
  /// for high-traffic scenarios.
  Future<double?> getTailorAverageRating(String tailorId) async {
    try {
      final snap = await _db
          .collection(_reviews)
          .where('targetId', isEqualTo: tailorId)
          .where('targetRole', isEqualTo: ReviewTargetRole.tailor.name)
          .get();

      if (snap.docs.isEmpty) return null;

      final total = snap.docs.fold<double>(
        0,
        (sum, d) => sum + ((d.data()['rating'] as num?)?.toDouble() ?? 0),
      );

      return total / snap.docs.length;
    } on FirebaseException catch (e) {
      throw PortfolioServiceException(
        'Failed to calculate average rating: ${e.message ?? e.code}',
      );
    }
  }
}