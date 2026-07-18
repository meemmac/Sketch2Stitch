import 'package:flutter/material.dart';

enum TrackEventType { requested, confirmed, dismissed }

class TrackEvent {
  final TrackEventType type;
  final String material;
  final String partyName;

  const TrackEvent({
    required this.type,
    required this.material,
    required this.partyName,
  });
}

class OrderTrackScreen extends StatelessWidget {
  final String orderId;
  final String status;
  final String estimatedDelivery;
  final String lastUpdated;
  final String deliveryAddress;
  final List<TrackEvent> events;

  const OrderTrackScreen({
    super.key,
    this.orderId = 'OR05',
    this.status = 'Waiting for checkout',
    this.estimatedDelivery = '-',
    this.lastUpdated = '22 Dec 2026',
    this.deliveryAddress = 'The Shakespeare Centre, Henley Street, CV37 6QW Stratford-upon-Avon, UK.',
    // TODO: replace with the real order's event history from the backend
    this.events = const [
      TrackEvent(type: TrackEventType.requested, material: 'Fine Cotton', partyName: 'Cotton Palace'),
      TrackEvent(type: TrackEventType.requested, material: 'Embroidery', partyName: 'Jhakanaka Embroidery Place'),
      TrackEvent(type: TrackEventType.requested, material: 'Linen', partyName: 'Mukta Kapors'),
      TrackEvent(type: TrackEventType.confirmed, material: 'Fine Cotton', partyName: 'Cotton Palace'),
      TrackEvent(type: TrackEventType.dismissed, material: 'Embroidery', partyName: 'Jhakanaka Embroidery Place'),
      TrackEvent(type: TrackEventType.confirmed, material: 'Linen', partyName: 'Mukta Kapors'),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking Order for Order ID: $orderId',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildDeliveryAddressCard(),
                    const SizedBox(height: 28),
                    _buildTimeline(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Top bar ----------------
  Widget _buildTopBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade200, Colors.green.shade50],
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/transparent_logo.png',
            height: 30,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.checkroom_rounded, size: 26, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          const Text('Sketch2Stitch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Back to Home', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  // ---------------- Status summary card ----------------
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(child: _statusColumn(Icons.shopping_cart_outlined, status, 'Status')),
          _verticalDivider(),
          Expanded(child: _statusColumn(Icons.hourglass_empty_rounded, estimatedDelivery, 'Estimated Delivery')),
          _verticalDivider(),
          Expanded(child: _statusColumn(Icons.update_rounded, lastUpdated, 'Last Updated')),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 44, color: Colors.black12);
  }

  Widget _statusColumn(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.black87),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.black.withOpacity(0.5))),
      ],
    );
  }

  // ---------------- Delivery address card ----------------
  Widget _buildDeliveryAddressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFD7EFD8), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Address', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          Text(
            deliveryAddress,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black.withOpacity(0.65)),
          ),
        ],
      ),
    );
  }

  // ---------------- Timeline ----------------
  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(events.length, (index) {
        final bool isLast = index == events.length - 1;
        return _buildTimelineItem(events[index], isLast);
      }),
    );
  }

  Widget _buildTimelineItem(TrackEvent event, bool isLast) {
    final style = _styleFor(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                child: Icon(style.icon, size: 12, color: Colors.white),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22, top: 2),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                  children: [
                    TextSpan(text: '${style.verb} for '),
                    TextSpan(text: event.material, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ' from '),
                    TextSpan(text: event.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TrackEventStyle _styleFor(TrackEventType type) {
    switch (type) {
      case TrackEventType.requested:
        return _TrackEventStyle(color: Colors.blue.shade600, icon: Icons.north_east_rounded, verb: 'Requested');
      case TrackEventType.confirmed:
        return _TrackEventStyle(color: Colors.green.shade600, icon: Icons.check_rounded, verb: 'Order confirmed');
      case TrackEventType.dismissed:
        return _TrackEventStyle(color: Colors.red.shade500, icon: Icons.close_rounded, verb: 'Order dismissed');
    }
  }
}

class _TrackEventStyle {
  final Color color;
  final IconData icon;
  final String verb;

  const _TrackEventStyle({required this.color, required this.icon, required this.verb});
}