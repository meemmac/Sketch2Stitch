import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/measurement.dart';

/// Thrown by [MeasurementService] with a user-friendly message so callers
/// can surface `e.message` directly without knowing Firestore error codes.
class MeasurementServiceException implements Exception {
  const MeasurementServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Wraps all Firestore operations on the `Measurement` collection (and the
/// `Tailor-jobs` collection for [getMeasurementByTailorJob]).
///
/// Every method maps directly to the schema documented in the collection spec:
///
/// **Measurement** fields:
///   customerId, ankle, hipsCircumference, roundShoulderCircumference,
///   shoulderToBust, shoulderToKnee, shoulderToUnderBust, thigh,
///   underBustCircumference, upperBustCircumference, knee, bustCircumference,
///   waist, shoulderToAnkle, waistToAnkle
class MeasurementService {
  MeasurementService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _measurements = 'Measurement';
  static const _tailorJobs = 'Tailor-jobs';

  // ── getMeasurement ─────────────────────────────────────────────────────────

  /// Returns the first [Measurement] document that belongs to [customerId],
  /// or `null` when the customer has no measurement on record yet.
  ///
  /// Queries the `Measurement` collection where `customerId == customerId`.
  Future<Measurement?> getMeasurement(String customerId) async {
    try {
      final snap = await _db
          .collection(_measurements)
          .where('customerId', isEqualTo: customerId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final doc = snap.docs.first;
      return Measurement.fromJson({...doc.data(), 'id': doc.id});
    } on FirebaseException catch (e) {
      throw MeasurementServiceException(
        'Failed to fetch measurement: ${e.message ?? e.code}',
      );
    }
  }

  // ── createMeasurement ──────────────────────────────────────────────────────

  /// Creates a new measurement document for [customerId] in the `Measurement`
  /// collection and returns the saved [Measurement] (with its generated id).
  ///
  /// [data] must be a [Map] containing any subset of the Measurement fields
  /// (all numeric fields default to 0 when omitted — see [Measurement]).
  Future<Measurement> createMeasurement(
    String customerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(data)
        ..['customerId'] = customerId;

      final ref = await _db.collection(_measurements).add(payload);
      final snap = await ref.get();

      return Measurement.fromJson({...snap.data()!, 'id': snap.id});
    } on FirebaseException catch (e) {
      throw MeasurementServiceException(
        'Failed to create measurement: ${e.message ?? e.code}',
      );
    }
  }

  // ── updateMeasurement ──────────────────────────────────────────────────────

  /// Merges [data] into the existing `Measurement` document identified by
  /// [measurementId]. Only the supplied fields are overwritten; all others
  /// remain unchanged (Firestore `update` semantics).
  ///
  /// Returns the updated [Measurement].
  Future<Measurement> updateMeasurement(
    String measurementId,
    Map<String, dynamic> data,
  ) async {
    try {
      final ref = _db.collection(_measurements).doc(measurementId);
      await ref.update(data);
      final snap = await ref.get();

      if (!snap.exists) {
        throw const MeasurementServiceException(
          'Measurement not found after update.',
        );
      }

      return Measurement.fromJson({...snap.data()!, 'id': snap.id});
    } on MeasurementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw MeasurementServiceException(
        'Failed to update measurement: ${e.message ?? e.code}',
      );
    }
  }

  // ── deleteMeasurement ──────────────────────────────────────────────────────

  /// Permanently deletes the `Measurement` document with [measurementId].
  Future<void> deleteMeasurement(String measurementId) async {
    try {
      await _db.collection(_measurements).doc(measurementId).delete();
    } on FirebaseException catch (e) {
      throw MeasurementServiceException(
        'Failed to delete measurement: ${e.message ?? e.code}',
      );
    }
  }

  // ── getMeasurementByTailorJob ──────────────────────────────────────────────

  /// Looks up the `Tailor-jobs` document for [tailorJobId], reads its
  /// `measurementId` field, and returns the corresponding [Measurement].
  ///
  /// Returns `null` if the tailor job has no linked measurement or if the
  /// referenced measurement document does not exist.
  ///
  /// Collections touched: `Tailor-jobs` → `Measurement`.
  Future<Measurement?> getMeasurementByTailorJob(String tailorJobId) async {
    try {
      // Step 1: fetch the tailor job to get the measurementId.
      final jobSnap =
          await _db.collection(_tailorJobs).doc(tailorJobId).get();

      if (!jobSnap.exists) {
        throw MeasurementServiceException(
          'Tailor job "$tailorJobId" not found.',
        );
      }

      final measurementId =
          jobSnap.data()?['measurementId'] as String?;

      if (measurementId == null || measurementId.isEmpty) return null;

      // Step 2: fetch the measurement document.
      final measSnap =
          await _db.collection(_measurements).doc(measurementId).get();

      if (!measSnap.exists) return null;

      return Measurement.fromJson({...measSnap.data()!, 'id': measSnap.id});
    } on MeasurementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw MeasurementServiceException(
        'Failed to fetch measurement for tailor job: ${e.message ?? e.code}',
      );
    }
  }
}
