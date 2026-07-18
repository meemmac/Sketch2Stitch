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
  final String imagePath;
  final String color;
  final String paymentStatus;
  final String description;
  final bool canWash;
  final bool canBleach;
  final bool canDryClean;
  final bool canTumbleDry;
  final String ironLevel;

  const RetailerOrder({
    required this.id,
    required this.customerName,
    required this.itemName,
    required this.quantity,
    required this.amount,
    required this.orderDate,
    required this.status,
    required this.isDelivered,
    required this.imagePath,
    required this.color,
    required this.paymentStatus,
    this.deliveryDate,
    this.description = "Premium quality material with excellent durability and comfort.",
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.canTumbleDry = true,
    this.ironLevel = "Medium",
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
      customerName: "Nazia Tasphia",
      itemName: "Premium Egyptian Cotton",
      quantity: 8,
      amount: 5200,
      orderDate: DateTime.now().subtract(const Duration(days: 12)),
      status: "Preparing",
      isDelivered: false,
      imagePath: "assets/images/fabrics_rolled.jpg",
      color: "White",
      paymentStatus: "Unpaid",
      description: "Soft, breathable Egyptian cotton perfect for high-end shirts and summer wear.",
      canWash: true,
      canBleach: false,
      canDryClean: true,
      canTumbleDry: true,
      ironLevel: "High",
    ),
    RetailerOrder(
      id: "ORD-1083",
      customerName: "Israt Jahan",
      itemName: "Golden Silk Blend",
      quantity: 3,
      amount: 5400,
      orderDate: DateTime.now().subtract(const Duration(days: 28)),
      status: "Packed",
      isDelivered: false,
      imagePath: "assets/images/silk.jpg",
      color: "Gold",
      paymentStatus: "Paid",
      description: "Luxurious silk blend with a natural sheen and elegant drape.",
      canWash: false,
      canBleach: false,
      canDryClean: true,
      canTumbleDry: false,
      ironLevel: "Low",
    ),
    RetailerOrder(
      id: "ORD-1076",
      customerName: "Nishat Tasnim",
      itemName: "Linen Summer Fabric",
      quantity: 5,
      amount: 5600,
      orderDate: DateTime.now().subtract(const Duration(days: 43)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 35)),
      status: "Delivered",
      isDelivered: true,
      imagePath: "assets/images/fab2.jpg",
      color: "Light Blue",
      paymentStatus: "Paid",
      description: "Lightweight linen fabric, highly breathable and ideal for humid weather.",
      canWash: true,
      canBleach: false,
      canDryClean: true,
      canTumbleDry: false,
      ironLevel: "Medium",
    ),
    RetailerOrder(
      id: "ORD-1051",
      customerName: "Farzana Yasmin",
      itemName: "Printed Scarf",
      quantity: 12,
      amount: 4560,
      orderDate: DateTime.now().subtract(const Duration(days: 96)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 89)),
      status: "Delivered",
      isDelivered: true,
      imagePath: "assets/images/gorgeous.jpg",
      color: "Multi",
      paymentStatus: "Paid",
      description: "Vibrant seasonal patterns on soft, comfortable material.",
      canWash: true,
      canBleach: false,
      canDryClean: false,
      canTumbleDry: true,
      ironLevel: "Low",
    ),
    RetailerOrder(
      id: "ORD-1018",
      customerName: "Jaima Haque",
      itemName: "Denim Work Shirt",
      quantity: 4,
      amount: 3680,
      orderDate: DateTime.now().subtract(const Duration(days: 142)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 134)),
      status: "Delivered",
      isDelivered: true,
      imagePath: "assets/images/denim.jpg",
      color: "Indigo",
      paymentStatus: "Paid",
      description: "Durable denim construction designed for longevity and style.",
      canWash: true,
      canBleach: false,
      canDryClean: true,
      canTumbleDry: true,
      ironLevel: "Medium",
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
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
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
        color: const Color(0xFF67B36B),
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
    return GestureDetector(
      onTap: () => _showOrderPreview(order),
      child: Container(
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    order.imagePath,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 52,
                      height: 52,
                      color: Colors.green.shade50,
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
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
                    const SizedBox(height: 4),
                    Text(
                      order.paymentStatus,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
                _orderInfo(Icons.palette_outlined, order.color),
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
      ),
    );
  }

  Future<void> _showOrderPreview(RetailerOrder order) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    order.imagePath,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 250,
                      width: double.infinity,
                      color: Colors.green.shade50,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 50,
                        color: Colors.green.shade200,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.itemName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      "Tk ${order.amount.toInt()}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoBadge(
                      "Order: ${order.id}",
                      Colors.blue.shade50,
                      Colors.blue.shade800,
                    ),
                    _infoBadge(
                      order.status,
                      Colors.orange.shade50,
                      Colors.orange.shade800,
                    ),
                    _infoBadge(
                      "Color: ${order.color}",
                      Colors.green.shade50,
                      Colors.green.shade800,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Product Description",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  order.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "Care Instructions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                _careInfoRow(Icons.wash, "Machine Washable", order.canWash),
                _careInfoRow(Icons.biotech, "Bleach Allowed", order.canBleach),
                _careInfoRow(
                  Icons.dry_cleaning,
                  "Dry Clean Only",
                  order.canDryClean,
                ),
                _careInfoRow(
                  Icons.settings_input_component,
                  "Tumble Dry",
                  order.canTumbleDry,
                ),
                _careInfoRow(
                  Icons.iron,
                  "Iron Level",
                  true,
                  trailing: order.ironLevel,
                ),
                const SizedBox(height: 30),
                const Text(
                  "Order Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _detailRow("Customer", order.customerName),
                _detailRow("Quantity", "${order.quantity} units"),
                _detailRow("Order Date", _formatDate(order.orderDate)),
                if (order.deliveryDate != null)
                  _detailRow("Delivery Date", _formatDate(order.deliveryDate!)),
                _detailRow("Payment Status", order.paymentStatus),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _careInfoRow(
    IconData icon,
    String label,
    bool isOk, {
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isOk ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: isOk ? Colors.black87 : Colors.grey),
            ),
          ),
          Text(
            trailing ?? (isOk ? "Yes" : "No"),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.green.shade800 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
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
