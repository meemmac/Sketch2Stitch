import 'package:flutter/material.dart';

class RetailerOrder {
  final String id;
  final String customerName;
  final String itemName;
  final int quantity;
  final double amount;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String status;
  final bool isDelivered;

  const RetailerOrder({
    required this.id,
    required this.customerName,
    required this.itemName,
    required this.quantity,
    required this.amount,
    required this.orderDate,
    required this.status,
    required this.isDelivered,
    this.deliveryDate,
  });
}

enum OrderFilterPreset { last3Months, last6Months, custom }

class RetailerOrdersScreen extends StatefulWidget {
  const RetailerOrdersScreen({super.key});

  @override
  State<RetailerOrdersScreen> createState() => _RetailerOrdersScreenState();
}

class _RetailerOrdersScreenState extends State<RetailerOrdersScreen> {
  OrderFilterPreset _filterPreset = OrderFilterPreset.last3Months;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  late final List<RetailerOrder> _orders = <RetailerOrder>[
    RetailerOrder(
      id: "ORD-1087",
      customerName: "Nadia Rahman",
      itemName: "Premium Egyptian Cotton",
      quantity: 8,
      amount: 5200,
      orderDate: DateTime.now().subtract(const Duration(days: 12)),
      status: "Preparing",
      isDelivered: false,
    ),
    RetailerOrder(
      id: "ORD-1083",
      customerName: "Arif Hossain",
      itemName: "Golden Silk Blend",
      quantity: 3,
      amount: 5400,
      orderDate: DateTime.now().subtract(const Duration(days: 28)),
      status: "Packed",
      isDelivered: false,
    ),
    RetailerOrder(
      id: "ORD-1076",
      customerName: "Sadia Islam",
      itemName: "Linen Summer Fabric",
      quantity: 5,
      amount: 5600,
      orderDate: DateTime.now().subtract(const Duration(days: 43)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 35)),
      status: "Delivered",
      isDelivered: true,
    ),
    RetailerOrder(
      id: "ORD-1051",
      customerName: "Tanvir Ahmed",
      itemName: "Printed Scarf",
      quantity: 12,
      amount: 4560,
      orderDate: DateTime.now().subtract(const Duration(days: 96)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 89)),
      status: "Delivered",
      isDelivered: true,
    ),
    RetailerOrder(
      id: "ORD-1018",
      customerName: "Maliha Chowdhury",
      itemName: "Denim Work Shirt",
      quantity: 4,
      amount: 3680,
      orderDate: DateTime.now().subtract(const Duration(days: 142)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 134)),
      status: "Delivered",
      isDelivered: true,
    ),
  ];

  DateTime get _startDate {
    final today = DateTime.now();
    switch (_filterPreset) {
      case OrderFilterPreset.last3Months:
        return DateTime(today.year, today.month - 3, today.day);
      case OrderFilterPreset.last6Months:
        return DateTime(today.year, today.month - 6, today.day);
      case OrderFilterPreset.custom:
        return _customStartDate ??
            DateTime(today.year, today.month - 3, today.day);
    }
  }

  DateTime get _endDate {
    final today = DateTime.now();
    if (_filterPreset == OrderFilterPreset.custom && _customEndDate != null) {
      return _customEndDate!;
    }

    return DateTime(today.year, today.month, today.day, 23, 59, 59);
  }

  String get _filterLabel {
    switch (_filterPreset) {
      case OrderFilterPreset.last3Months:
        return "Last 3 months";
      case OrderFilterPreset.last6Months:
        return "Last 6 months";
      case OrderFilterPreset.custom:
        if (_customStartDate == null || _customEndDate == null) {
          return "Custom dates";
        }

        return "${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}";
    }
  }

  List<RetailerOrder> get _filteredOrders {
    return _orders.where((order) {
      final date = order.orderDate;
      return !date.isBefore(_startDate) && !date.isAfter(_endDate);
    }).toList();
  }

  List<RetailerOrder> get _ongoingOrders {
    return _filteredOrders.where((order) => !order.isDelivered).toList();
  }

  List<RetailerOrder> get _deliveredOrders {
    return _filteredOrders.where((order) => order.isDelivered).toList();
  }

  Future<void> _pickCustomDateRange() async {
    final initialStart =
        _customStartDate ?? DateTime.now().subtract(const Duration(days: 30));
    final selectedEnd = _customEndDate ?? DateTime.now();
    final initialEnd = DateTime(
      selectedEnd.year,
      selectedEnd.month,
      selectedEnd.day,
    );
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.green.shade800,
              secondary: Colors.green.shade100,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null) {
      return;
    }

    setState(() {
      _filterPreset = OrderFilterPreset.custom;
      _customStartDate = range.start;
      _customEndDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                "Filter orders",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _filterOptionTile(
                title: "Last 3 months",
                subtitle: "Show recent retailer orders",
                selected: _filterPreset == OrderFilterPreset.last3Months,
                onTap: () {
                  setState(() {
                    _filterPreset = OrderFilterPreset.last3Months;
                  });
                  Navigator.pop(context);
                },
              ),
              _filterOptionTile(
                title: "Last 6 months",
                subtitle: "Review a longer order period",
                selected: _filterPreset == OrderFilterPreset.last6Months,
                onTap: () {
                  setState(() {
                    _filterPreset = OrderFilterPreset.last6Months;
                  });
                  Navigator.pop(context);
                },
              ),
              _filterOptionTile(
                title: "Start to end date",
                subtitle: _customStartDate == null || _customEndDate == null
                    ? "Choose a custom date range"
                    : "${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}",
                selected: _filterPreset == OrderFilterPreset.custom,
                onTap: () {
                  Navigator.pop(context);
                  _pickCustomDateRange();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterOptionTile({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: CircleAvatar(
        backgroundColor: selected ? Colors.green.shade800 : Colors.green.shade50,
        child: Icon(
          selected ? Icons.check : Icons.calendar_month_outlined,
          color: selected ? Colors.white : Colors.green.shade800,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Orders",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Tooltip(
                  message: "Filter orders",
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _showFilterSheet,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune,
                              color: Colors.green.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _filterLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _orderSummary(),
            const SizedBox(height: 20),
            _ordersSection(
              title: "Ongoing Orders",
              icon: Icons.local_shipping_outlined,
              orders: _ongoingOrders,
              emptyText: "No ongoing orders for this filter",
            ),
            const SizedBox(height: 18),
            _ordersSection(
              title: "Delivered Orders",
              icon: Icons.check_circle_outline,
              orders: _deliveredOrders,
              emptyText: "No delivered orders for this filter",
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade800,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _summaryItem("Ongoing", _ongoingOrders.length.toString()),
          Container(width: 1, height: 38, color: Colors.white24),
          _summaryItem("Delivered", _deliveredOrders.length.toString()),
          Container(width: 1, height: 38, color: Colors.white24),
          _summaryItem("Total", _filteredOrders.length.toString()),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersSection({
    required String title,
    required IconData icon,
    required List<RetailerOrder> orders,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green.shade800, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                orders.length.toString(),
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _emptyOrdersCard(emptyText)
        else
          ...orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderCard(order),
            ),
          ),
      ],
    );
  }

  Widget _emptyOrdersCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _orderCard(RetailerOrder order) {
    final statusColor = order.isDelivered ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.receipt_long, color: Colors.green.shade800),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${order.id} - ${order.customerName}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    color: statusColor.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _orderInfo(
                Icons.shopping_bag_outlined,
                "Qty ${order.quantity}",
              ),
              const SizedBox(width: 10),
              _orderInfo(
                Icons.calendar_today_outlined,
                _formatDate(order.orderDate),
              ),
              const Spacer(),
              Text(
                "Tk ${order.amount.toInt()}",
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (order.deliveryDate != null) ...[
            const SizedBox(height: 10),
            Text(
              "Delivered on ${_formatDate(order.deliveryDate!)}",
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _orderInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.black45),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }
}
