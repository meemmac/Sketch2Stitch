import 'package:flutter/material.dart';

import '../../models/measurement.dart';
import '../../services/measurement_service.dart';
import 'measurement_screen.dart'; // wherever MeasurementScreen actually lives

/// Entry point for the measurements flow. Handles:
///  - fetching the customer's existing measurement, or
///  - creating a fresh all-zero record if this is their first visit
///    (e.g. right after registration)
///  - saving edits back to Firestore, including the id-not-yet-assigned
///    case for a freshly-created record.
///
/// Usage: Navigator.push(context, MaterialPageRoute(
///   builder: (_) => MeasurementPage(customerId: currentUser.id),
/// ));
class MeasurementPage extends StatefulWidget {
  const MeasurementPage({super.key, required this.customerId});

  final String customerId;

  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage> {
  final _service = MeasurementService();
  late Future<Measurement> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getOrCreateMeasurement(widget.customerId);
  }

  Future<void> _retry() {
    final f = _service.getOrCreateMeasurement(widget.customerId);
    setState(() => _future = f);
    return f;
  }

  Future<void> _handleSave(Measurement updated) async {
    if (updated.isNew) {
      // Shouldn't normally happen since getOrCreateMeasurement always
      // returns a saved doc, but guard for it anyway.
      await _service.createMeasurement(widget.customerId, updated.toJson());
    } else {
      await _service.updateMeasurement(updated.id, updated.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Measurement>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load measurements.\n${snapshot.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _future =
                            _service.getOrCreateMeasurement(widget.customerId);
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MeasurementScreen(
          measurement: snapshot.data!,
          onSave: _handleSave,
        );
      },
    );
  }
}