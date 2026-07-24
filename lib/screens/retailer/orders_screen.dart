import 'package:flutter/material.dart';
import 'reviews_screen.dart';

class OrderItem {
  final String name;
  final int quantity;
  final String imagePath;
  final String color;
  final String description;
  final String? itemComment;
  final bool canWash;
  final bool canBleach;
  final bool canDryClean;
  final bool canTumbleDry;
  final String ironLevel;
  final double price;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.imagePath,
    required this.color,
    required this.price,
    this.description =
    "Premium quality material with excellent durability and comfort.",
    this.itemComment,
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.canTumbleDry = true,
    this.ironLevel = "Medium",
  });
}

class RetailerOrder {
  final String id;
  final String customerName;
  final String? tailorName;
  final List<OrderItem> items;
  final double amount;
  final DateTime orderDate;
  DateTime? deliveryDate;
  String status;
  bool isDelivered;
  final String? review;
  final double? rating;
  final String recipientType; // "Customer" or "Tailor"
  final String deliveryAddress;

  RetailerOrder({
    required this.id,
    required this.customerName,
    this.tailorName,
    required this.items,
    required this.amount,
    required this.orderDate,
    required this.status,
    required this.isDelivered,
    required this.recipientType,
    required this.deliveryAddress,
    this.deliveryDate,
    this.review,
    this.rating,
  });

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}

enum OrderFilterPreset { last3Months, last6Months, custom }

class RetailerOrdersScreen extends StatefulWidget {
  const RetailerOrdersScreen({super.key});

  @override
  State<RetailerOrdersScreen> createState() => _RetailerOrdersScreenState();
}

class _RetailerOrdersScreenState extends State<RetailerOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  OrderFilterPreset _filterPreset = OrderFilterPreset.last3Months;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _showOngoing = true;

  // Primary color: #4F7942
  final Color primaryGreen = const Color(0xFF4F7942);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  late final List<RetailerOrder> _orders = <RetailerOrder>[
    RetailerOrder(
      id: "ORD-1087",
      customerName: "Nazia Tasphia",
      tailorName: "Master Stitch",
      amount: 5200,
      orderDate: DateTime.now().subtract(const Duration(days: 12)),
      status: "Preparing",
      isDelivered: false,
      recipientType: "Tailor",
      deliveryAddress: "123 Stitch St, Dhaka Fashion District",
      items: [
        OrderItem(
          name: "Premium Egyptian Cotton",
          quantity: 5,
          price: 3250,
          imagePath: "assets/images/fabrics_rolled.jpg",
          color: "White",
          description:
          "Soft, breathable Egyptian cotton perfect for high-end shirts.",
          itemComment: "The cotton texture is incredibly smooth.",
          ironLevel: "High",
        ),
        OrderItem(
          name: "Denim Patchwork",
          quantity: 3,
          price: 1950,
          imagePath: "assets/images/denim.jpg",
          color: "Blue",
          canBleach: true,
        ),
      ],
    ),
    RetailerOrder(
      id: "ORD-1083",
      customerName: "Israt Jahan",
      amount: 5400,
      orderDate: DateTime.now().subtract(const Duration(days: 28)),
      status: "Packed",
      isDelivered: false,
      recipientType: "Customer",
      deliveryAddress: "House 45, Road 12, Banani, Dhaka",
      items: [
        OrderItem(
          name: "Golden Silk Blend",
          quantity: 3,
          price: 5400,
          imagePath: "assets/images/silk.jpg",
          color: "Gold",
          description: "Luxurious silk blend with a natural sheen.",
          itemComment: "Exactly the shade of gold I needed.",
          canWash: false,
          canTumbleDry: false,
          ironLevel: "Low",
        ),
      ],
    ),
    RetailerOrder(
      id: "ORD-1076",
      customerName: "Nishat Tasnim",
      amount: 8600,
      orderDate: DateTime.now().subtract(const Duration(days: 43)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 35)),
      status: "Delivered",
      isDelivered: true,
      recipientType: "Customer",
      deliveryAddress: "Dhanmondi 27, Dhaka",
      review: "Amazing quality fabric! The selection was perfect.",
      rating: 4.8,
      items: [
        OrderItem(
          name: "Linen Summer Fabric",
          quantity: 5,
          price: 5600,
          imagePath: "assets/images/fab2.jpg",
          color: "Light Blue",
          description: "Lightweight linen fabric, highly breathable.",
          itemComment: "The linen is so soft and cool.",
          canTumbleDry: false,
        ),
        OrderItem(
          name: "Printed Scarf",
          quantity: 5,
          price: 3000,
          imagePath: "assets/images/gorgeous.jpg",
          color: "Multi",
        ),
      ],
    ),
    RetailerOrder(
      id: "ORD-1051",
      customerName: "Farzana Yasmin",
      tailorName: "Royal Stitch",
      amount: 4560,
      orderDate: DateTime.now().subtract(const Duration(days: 96)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 89)),
      status: "Delivered",
      isDelivered: true,
      recipientType: "Tailor",
      deliveryAddress: "Shop 12, Gulshan Market, Dhaka",
      review: "Very soft and beautiful patterns. Delivery was fast.",
      rating: 4.5,
      items: [
        OrderItem(
          name: "Printed Scarf",
          quantity: 12,
          price: 4560,
          imagePath: "assets/images/gorgeous.jpg",
          color: "Multi",
          description: "Vibrant seasonal patterns on soft material.",
          canDryClean: false,
          ironLevel: "Low",
        ),
      ],
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
    }).where((order) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final matchesId = order.id.toLowerCase().contains(query);
      final matchesCustomer = order.customerName.toLowerCase().contains(query);
      final matchesProduct = order.items.any((i) => i.name.toLowerCase().contains(query));
      return matchesId || matchesCustomer || matchesProduct;
    }).toList();
  }

  List<RetailerOrder> get _ongoingOrders {
    return _filteredOrders.where((order) => !order.isDelivered).toList();
  }

  List<RetailerOrder> get _deliveredOrders {
    return _filteredOrders.where((order) => order.isDelivered).toList();
  }

  void _updateOrderStatus(RetailerOrder order, String newStatus) {
    setState(() {
      order.status = newStatus;
      if (newStatus == "Delivered") {
        order.isDelivered = true;
        order.deliveryDate = DateTime.now();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Order ${order.id} marked as Delivered")),
        );
      }
    });
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
              primary: primaryGreen,
              secondary: primaryGreen.withValues(alpha: 0.1),
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
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
        backgroundColor: selected ? primaryGreen : Colors.green.shade50,
        child: Icon(
          selected ? Icons.check : Icons.calendar_month_outlined,
          color: selected ? Colors.white : primaryGreen,
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.08 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            24,
          ),
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
                Expanded(
                  child: Text(
                    "Orders",
                    style: TextStyle(
                      fontSize: screenWidth > 400 ? 30 : 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showDetailedFilterSheet,
                  icon: Icon(Icons.filter_list, color: primaryGreen),
                  tooltip: "Filter by names/IDs",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchAndFilter(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _sectionToggle(
                    label: "Ongoing",
                    isSelected: _showOngoing,
                    count: _ongoingOrders.length,
                    onTap: () => setState(() => _showOngoing = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sectionToggle(
                    label: "Delivered",
                    isSelected: !_showOngoing,
                    count: _deliveredOrders.length,
                    onTap: () => setState(() => _showOngoing = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_showOngoing)
              _ordersSection(
                title: "Ongoing Orders",
                icon: Icons.local_shipping_outlined,
                orders: _ongoingOrders,
                emptyText: "No ongoing orders found",
              )
            else
              _ordersSection(
                title: "Delivered Orders",
                icon: Icons.check_circle_outline,
                orders: _deliveredOrders,
                emptyText: "No delivered orders found",
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: "Search order ID, product...",
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _filterButton(),
      ],
    );
  }

  void _showDetailedFilterSheet() {
    final TextEditingController filterController = TextEditingController(text: _searchQuery);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text("Detailed Filter", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                "Filter by Order ID, Product Name, or Customer",
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: filterController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Enter keywords...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = filterController.text;
                      _searchController.text = filterController.text;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Apply Filter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _showFilterSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
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
              color: primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _filterLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionToggle({
    required String label,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primaryGreen.withValues(alpha: 0.8)
                : Colors.green.shade100,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.green.shade900,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              "$count orders",
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
            Icon(icon, color: primaryGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
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
            if (title == "Delivered Orders") ...[
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RetailerReviewsScreen(
                        shopName: "Elegant Fabrics Ltd.",
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.star_outline, size: 16),
                label: const Text("See Reviews"),
                style: TextButton.styleFrom(
                  foregroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
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
    final Color statusColor =
    order.isDelivered ? primaryGreen : Colors.blueAccent;

    final firstItem = order.items.first;

    // Deliver to display logic
    String deliverToText = order.recipientType;
    if (!order.isDelivered && order.recipientType == "Tailor") {
      deliverToText = "Tailor (Pending)";
    }

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
                    firstItem.imagePath,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 52,
                      height: 52,
                      color: Colors.green.shade50,
                      child: Icon(Icons.receipt_long, color: primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Deliver To Section
                      Row(
                        children: [
                          Text(
                            order.isDelivered ? "Delivered to: " : "Deliver to: ",
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            deliverToText,
                            style: TextStyle(
                              color: order.recipientType == "Tailor" && !order.isDelivered
                                  ? Colors.orange.shade800
                                  : primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!order.isDelivered)
                      TextButton(
                        onPressed: () => _showStatusPicker(order),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 20),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Change",
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
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
                  "${order.totalQuantity} Units",
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
            if (order.isDelivered && order.rating != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.blue.shade800, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      order.rating.toString(),
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.review ?? "No overall review",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.blue.shade900.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  void _showStatusPicker(RetailerOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Update Order Status",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...["Preparing", "Packed", "Delivered"].map((s) => ListTile(
                title: Text(s),
                onTap: () {
                  _updateOrderStatus(order, s);
                  Navigator.pop(context);
                },
                trailing: order.status == s
                    ? Icon(Icons.check_circle, color: primaryGreen)
                    : null,
              )),
            ],
          ),
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
        initialChildSize: 0.9,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order Details",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        Text(
                          "ID: ${order.id}",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _infoBadge(
                    order.status,
                    order.isDelivered
                        ? primaryGreen.withValues(alpha: 0.1)
                        : Colors.blueAccent.withValues(alpha: 0.1),
                    order.isDelivered ? primaryGreen : Colors.blueAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!order.isDelivered)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showStatusPicker(order);
                  },
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                  label: const Text("Change Status",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const SizedBox(height: 25),
              const Text(
                "Products",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...order.items.map((item) => _itemPreviewCard(item)),
              const SizedBox(height: 30),
              const Text(
                "Order Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _detailRow("Customer", order.customerName),
              if (order.tailorName != null) _detailRow("Tailor", order.tailorName!),
              _detailRow("Total Quantity", "${order.totalQuantity} units"),
              _detailRow("Order Date", _formatDate(order.orderDate)),
              if (order.deliveryDate != null)
                _detailRow("Delivery Date", _formatDate(order.deliveryDate!)),
              const SizedBox(height: 8),
              const Text(
                "Delivery Address",
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.deliveryAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Grand Total",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
              if (order.isDelivered && order.review != null) ...[
                const SizedBox(height: 35),
                const Text(
                  "Overall Review",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ...List.generate(
                            5,
                                (index) => Icon(
                              index < (order.rating ?? 0).floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.blue.shade800,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            order.rating?.toString() ?? "0.0",
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "\"${order.review}\"",
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemPreviewCard(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  item.imagePath,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Qty: ${item.quantity} | Color: ${item.color}",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "Tk ${item.price.toInt()}",
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.description,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            "Care Instructions",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _careTag(Icons.wash, "Wash", item.canWash),
                _careTag(Icons.biotech, "Bleach", item.canBleach),
                _careTag(Icons.dry_cleaning, "Dry Clean", item.canDryClean),
                _careTag(
                    Icons.settings_input_component, "Tumble", item.canTumbleDry),
                _careTag(Icons.iron, "Iron: ${item.ironLevel}", true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _careTag(IconData icon, String label, bool isOk) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOk ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12, color: isOk ? Colors.green.shade700 : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.green.shade800 : Colors.grey,
            ),
          ),
        ],
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
              const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
