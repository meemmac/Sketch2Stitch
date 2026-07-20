import 'package:flutter/material.dart';
import 'package:sketch2stitch/widgets/dashboard_drawer.dart';
import 'track_order.dart';

class OrderListScreen extends StatefulWidget {
  final AppUserRole userRole;

  const OrderListScreen({
    super.key,
    this.userRole = AppUserRole.customer,
  });

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  // Dummy order data with all statuses
  final List<Map<String, dynamic>> _orders = [
    {
      'id': 'OR001',
      'status': 'Pending Retailer Confirmation',
      'date': '22 Dec 2026',
      'items': 3,
      'total': '৳ 4,500',
      'statusColor': Colors.orange,
      'estimatedDelivery': '25 Dec 2026',
      'lastUpdated': '22 Dec 2026',
      'deliveryAddress': 'The Shakespeare Centre, Henley Street, CV37 6QW Stratford-upon-Avon, UK.',
      'events': [
        TrackEvent(type: TrackEventType.orderPlaced, material: '', partyName: 'Sketch2Stitch', date: DateTime(2026, 12, 20)),
        TrackEvent(type: TrackEventType.subOrderPreparing, material: 'Fine Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 20)),
        TrackEvent(type: TrackEventType.subOrderPacked, material: 'Fine Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 21)),
        TrackEvent(type: TrackEventType.awaitingTailorSelection, material: '', partyName: 'You', date: DateTime(2026, 12, 21)),
      ],
    },
    {
      'id': 'OR002',
      'status': 'Order Confirmed from Retailer(s)',
      'date': '23 Dec 2026',
      'items': 2,
      'total': '৳ 6,200',
      'statusColor': Colors.blue,
      'estimatedDelivery': '28 Dec 2026',
      'lastUpdated': '23 Dec 2026',
      'deliveryAddress': '123 Retailer Street, Dhaka, Bangladesh',
      'events': [
        TrackEvent(type: TrackEventType.orderPlaced, material: '', partyName: 'Sketch2Stitch', date: DateTime(2026, 12, 22)),
        TrackEvent(type: TrackEventType.subOrderPreparing, material: 'Silk Fabric', partyName: 'Silk House', date: DateTime(2026, 12, 22)),
        TrackEvent(type: TrackEventType.subOrderPacked, material: 'Silk Fabric', partyName: 'Silk House', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.orderConfirmedRetailer, material: 'Silk Fabric', partyName: 'Silk House', date: DateTime(2026, 12, 23)),
      ],
    },
    {
      'id': 'OR003',
      'status': 'Order Confirmed from Tailor',
      'date': '24 Dec 2026',
      'items': 4,
      'total': '৳ 8,900',
      'statusColor': Colors.purple,
      'estimatedDelivery': '30 Dec 2026',
      'lastUpdated': '24 Dec 2026',
      'deliveryAddress': '45 Tailor Lane, Dhaka, Bangladesh',
      'events': [
        TrackEvent(type: TrackEventType.orderPlaced, material: '', partyName: 'Sketch2Stitch', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.subOrderPreparing, material: 'Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.subOrderPacked, material: 'Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 24)),
        TrackEvent(type: TrackEventType.tailorRequested, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 24)),
        TrackEvent(type: TrackEventType.tailorConfirmed, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 24)),
      ],
    },
    {
      'id': 'OR004',
      'status': 'Shipping to Tailor',
      'date': '25 Dec 2026',
      'items': 2,
      'total': '৳ 6,200',
      'statusColor': Colors.teal,
      'estimatedDelivery': '28 Dec 2026',
      'lastUpdated': '25 Dec 2026',
      'deliveryAddress': '123 Tailor Street, Dhaka, Bangladesh',
      'events': [
        TrackEvent(type: TrackEventType.orderPlaced, material: '', partyName: 'Sketch2Stitch', date: DateTime(2026, 12, 22)),
        TrackEvent(type: TrackEventType.subOrderPreparing, material: 'Silk Fabric', partyName: 'Silk House', date: DateTime(2026, 12, 22)),
        TrackEvent(type: TrackEventType.subOrderPacked, material: 'Silk Fabric', partyName: 'Silk House', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.tailorRequested, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.tailorConfirmed, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.shippingToTailor, material: 'Silk Fabric', partyName: 'Master Tailor', date: DateTime(2026, 12, 24)),
      ],
    },
    {
      'id': 'OR005',
      'status': 'Shipping to Customer',
      'date': '26 Dec 2026',
      'items': 4,
      'total': '৳ 8,900',
      'statusColor': Colors.indigo,
      'estimatedDelivery': '30 Dec 2026',
      'lastUpdated': '26 Dec 2026',
      'deliveryAddress': '45 Customer Lane, Dhaka, Bangladesh',
      'events': [
        TrackEvent(type: TrackEventType.orderPlaced, material: '', partyName: 'Sketch2Stitch', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.subOrderPreparing, material: 'Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 23)),
        TrackEvent(type: TrackEventType.subOrderPacked, material: 'Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 24)),
        TrackEvent(type: TrackEventType.tailorConfirmed, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 24)),
        TrackEvent(type: TrackEventType.tailorCompleted, material: 'Custom Dress', partyName: 'Master Tailor', date: DateTime(2026, 12, 28)),
        TrackEvent(type: TrackEventType.shippingToCustomer, material: 'Custom Dress', partyName: 'DHL Express', date: DateTime(2026, 12, 29)),
      ],
    },
    {
      'id': 'OR006',
      'status': 'Delivered',
      'date': '27 Dec 2026',
      'items': 1,
      'total': '৳ 2,300',
      'statusColor': Colors.green,
      'estimatedDelivery': '27 Dec 2026',
      'lastUpdated': '27 Dec 2026',
      'deliveryAddress': '78 New Market Road, Dhaka, Bangladesh',
      'events': [
        TrackEvent(type: TrackEventType.orderPlaced, material: '', partyName: 'Sketch2Stitch', date: DateTime(2026, 12, 25)),
        TrackEvent(type: TrackEventType.subOrderPreparing, material: 'Linen', partyName: 'Mukta Kapors', date: DateTime(2026, 12, 25)),
        TrackEvent(type: TrackEventType.subOrderPacked, material: 'Linen', partyName: 'Mukta Kapors', date: DateTime(2026, 12, 25)),
        TrackEvent(type: TrackEventType.subOrderDelivered, material: 'Linen', partyName: 'Customer', date: DateTime(2026, 12, 25)),
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text(
              'My Orders',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _orders.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _buildOrderCard(order);
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
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Orders Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your orders will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _navigateToOrderTrack(context, order);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: order['statusColor'],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Order #${order['id']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Last Update',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          order['date'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${order['items']} items',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order['total'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (order['statusColor'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order['status'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: order['statusColor'],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Track',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToOrderTrack(BuildContext context, Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackScreen(
          orderId: order['id'],
          status: order['status'],
          estimatedDelivery: order['estimatedDelivery'],
          lastUpdated: order['lastUpdated'],
          deliveryAddress: order['deliveryAddress'],
          events: order['events'],
          userRole: widget.userRole,
        ),
      ),
    );
  }
}