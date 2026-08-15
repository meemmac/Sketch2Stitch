import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/measurement.dart';
import '../../../models/tailor.dart';
import 'reviews_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/tailor_service.dart';
import '../../../services/user_session.dart';
import '../../../services/order_service.dart';
import '../../../models/tailor_job.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/top_feedback_banner.dart';

enum TailorOrderStatus { pending, confirmed, inProgress, ready, completed, cancelled }

class TailorOrderItem {
  final String name;
  final int quantity;
  final String imagePath;
  final String color;
  final List<String>? measurementRefImages;
  final String? tailorInstructions;
  final double productPrice;
  double servicePrice;
  DateTime? estimatedDeliveryDate;
  final bool canWash;
  final bool canBleach;
  final bool canDryClean;
  final String ironLevel;

  TailorOrderItem({
    required this.name,
    required this.quantity,
    required this.imagePath,
    required this.color,
    required this.productPrice,
    required this.servicePrice,
    this.measurementRefImages,
    this.tailorInstructions,
    this.estimatedDeliveryDate,
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.ironLevel = "Medium",
  });
}

class TailorOrder {
  final String id; // This is the Tailor-job document ID
  final String orderId; // This is the parent Orders document ID
  final String customerName;
  final String customerPhone;
  final List<TailorOrderItem> items;
  final double totalAmount;
  final DateTime orderDate;
  DateTime? completionDate;
  TailorOrderStatus status;
  bool isCompleted;
  final String? customerReview;
  final double? customerRating;
  final String deliveryAddress;
  final Measurement? measurement;

  TailorOrder({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    required this.orderDate,
    required this.status,
    required this.isCompleted,
    required this.deliveryAddress,
    this.completionDate,
    this.customerReview,
    this.customerRating,
    this.measurement,
  });

  int get totalQuantity => items.fold(0, (sumValue, item) => sumValue + item.quantity);
  double get totalServicePrice => items.fold(0, (sumValue, item) => sumValue + item.servicePrice);
  double get totalProductPrice => items.fold(0, (sumValue, item) => sumValue + item.productPrice);
}

enum OrderFilterPreset { last3Months, last6Months, custom }

class TailorOrdersScreen extends StatefulWidget {
  final Tailor? tailor; 

  const TailorOrdersScreen({super.key, this.tailor});

  @override
  State<TailorOrdersScreen> createState() => _TailorOrdersScreenState();
}

class _TailorOrdersScreenState extends State<TailorOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  OrderFilterPreset _filterPreset = OrderFilterPreset.last3Months;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int _selectedTabIndex = 1; // 0: Pending, 1: Current, 2: Completed
  String _selectedStatus = "All";
  late Tailor _tailor; 
  final TailorService _tailorService = TailorService();
  final OrderService _orderService = OrderService();
  StreamSubscription? _ordersSubscription;
  bool _isLoading = true;

  // Top feedback state (matching RegisterScreen)

  final Color primaryGreen = const Color(0xFF4F7942);

  @override
  void initState() {
    super.initState();
    if (widget.tailor != null) {
      _tailor = widget.tailor!;
    } else {
      _tailor = Tailor(
        id: "T-123",
        name: "Loading...",
        email: "",
        phone: "",
        address: "",
        rating: 5.0,
        maxOrder: null, // Defaults to Not Set (unlimited)
      );
      _fetchTailorProfile();
    }
    _listenToOrders();
  }

  void _listenToOrders() {
    final tailorId = UserSession.instance.uid;
    debugPrint("TailorOrdersScreen: Listening for Tailor ID: $tailorId");
    if (tailorId == null) {
      debugPrint("TailorOrdersScreen: No logged in user ID found.");
      return;
    }

    _ordersSubscription = _orderService.streamDetailedTailorOrders(tailorId).listen((data) {
      debugPrint("TailorOrdersScreen: Received ${data.length} jobs from stream.");
      if (!mounted) return;
      setState(() {
        _orders.clear();
        for (var map in data) {
          final job = map['job'];
          final order = map['order'];
          final customer = map['customer'];
          final items = map['items'] as List<dynamic>;
          final measurementMap = map['measurement'];

          debugPrint("TailorOrdersScreen: Processing job ${job['id']} with status ${job['status']}");

          _orders.add(TailorOrder(
            id: job['id'],
            orderId: order['id'],
            customerName: customer['name'] ?? 'N/A',
            customerPhone: customer['phone'] ?? 'N/A',
            totalAmount: (job['quoteAmount'] ?? 0).toDouble() + (job['deliveryCharge'] ?? 0).toDouble(),
            orderDate: _parseDateTime(job['createdAt'] ?? order['orderDate']) ?? DateTime.now(),
            status: _mapStatus(job['status']),
            isCompleted: job['status'] == 'completed',
            completionDate: job['status'] == 'completed' ? _parseDateTime(job['confirmedAt']) : null, 
            deliveryAddress: customer['address'] ?? 'N/A',
            measurement: measurementMap != null ? Measurement.fromJson({...measurementMap, 'id': job['measurementId']}) : null,
            items: items.map((i) {
              final careSymbols = List<String>.from(i['careSymbol'] ?? []);
              return TailorOrderItem(
                name: i['name'],
                quantity: i['quantity'],
                imagePath: i['imagePath'],
                color: i['color'],
                productPrice: i['price'],
                servicePrice: (job['quoteAmount'] ?? 0).toDouble(),
                tailorInstructions: job['specialInstructions'] ?? i['instructions'],
                estimatedDeliveryDate: _parseDateTime(job['estimatedDeliveryDate']),
                measurementRefImages: job['designIds'] != null ? List<String>.from(job['designIds']) : [],
                canWash: careSymbols.contains('wash'),
                canBleach: careSymbols.contains('bleach'),
                canDryClean: careSymbols.contains('dryClean'),
                ironLevel: careSymbols.firstWhere((s) => s.startsWith('iron'), orElse: () => "Medium"),
              );
            }).toList(),
          ));
        }
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint("TailorOrdersScreen: Error in stream: $e");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  TailorOrderStatus _mapStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending': return TailorOrderStatus.pending;
      // Quote sent — the tailor is done, it's the customer's move now. Groups
      // with 'confirmed' so a quoted job doesn't fall back into the Pending
      // bucket and look like it still needs a response.
      case 'quoted':
      case 'confirmed': return TailorOrderStatus.confirmed;
      case 'in_progress': return TailorOrderStatus.inProgress;
      case 'ready': return TailorOrderStatus.ready;
      case 'completed': return TailorOrderStatus.completed;
      case 'cancelled':
      case 'tailor_declined':
      case 'rejected':
        return TailorOrderStatus.cancelled;
      default: return TailorOrderStatus.pending;
    }
  }

  Future<void> _fetchTailorProfile() async {
    final uid = UserSession.instance.uid;
    if (uid != null) {
      final t = await _tailorService.getTailorProfile(uid);
      if (t != null && mounted) {
        setState(() {
          _tailor = t;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void _showBanner(String message, {bool isError = true}) {
    // Single app-wide top banner; also visible over bottom sheets.
    AppFeedback.show(context, message, isError: isError);
  }

  final List<TailorOrder> _orders = [];

  /*
  final Measurement _mockMeasurement = Measurement(
    id: "meas_123",
    customerId: "cust_456",
    upperBustCircumference: 34.5,
    roundShoulderCircumference: 40.0,
    hipsCircumference: 38.0,
    underBustCircumference: 32.0,
    bustCircumference: 36.0,
    waist: 28.5,
    shoulderToKnee: 37.0,
    shoulderToUnderBust: 13.0,
    shoulderToBust: 10.5,
    thigh: 22.0,
    knee: 15.0,
    ankle: 9.5,
    waistToAnkle: 40.0,
    shoulderToAnkle: 55.0,
  );

  late final List<TailorOrder> _dummyOrders = [
    TailorOrder(
      id: "T-ORD-1122",
      customerName: "Maria Doe",
      customerPhone: "+8801712345678",
      totalAmount: 1500,
      orderDate: DateTime.now().subtract(const Duration(days: 1)),
      status: TailorOrderStatus.pending,
      isCompleted: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        TailorOrderItem(
          name: "Premium Linen Kurti",
          quantity: 1,
          imagePath: "assets/images/fabrics_rolled.jpg",
          color: "Cream",
          productPrice: 1500,
          servicePrice: 0,
          measurementRefImages: ["assets/images/ref1.jpg", "assets/images/ref2.jpg"],
          tailorInstructions: "Please ensure the length is precisely 42 inches. Follow the reference image for sleeve design.",
          canWash: true,
          ironLevel: "High",
        ),
      ],
    ),
    TailorOrder(
      id: "T-ORD-1125",
      customerName: "Zeaul Alam",
      customerPhone: "+8801811223344",
      totalAmount: 2200,
      orderDate: DateTime.now().subtract(const Duration(hours: 5)),
      status: TailorOrderStatus.pending,
      isCompleted: false,
      deliveryAddress: "Gulshan 1, Dhaka",
      items: [
        TailorOrderItem(
          name: "Designer Silk Suit",
          quantity: 1,
          imagePath: "assets/images/silk.jpg",
          color: "Deep Blue",
          productPrice: 2200,
          servicePrice: 0,
          measurementRefImages: ["assets/images/ref3.jpg"],
          tailorInstructions: "Slim fit cut with narrow trousers.",
          canWash: false,
          canDryClean: true,
        ),
      ],
    ),
    TailorOrder(
      id: "T-ORD-1120",
      customerName: "Maria Doe",
      customerPhone: "+8801712345678",
      totalAmount: 3200,
      orderDate: DateTime.now().subtract(const Duration(days: 3)),
      status: TailorOrderStatus.inProgress,
      isCompleted: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        TailorOrderItem(
          name: "Printed Voile Summer Dress",
          quantity: 2,
          imagePath: "assets/images/gorgeous.jpg",
          color: "Floral Blue",
          productPrice: 1600,
          servicePrice: 1200,
          measurementRefImages: ["assets/images/ref2.jpg"],
          tailorInstructions: "Use the printed patterns for the sleeves as shown in the reference picture.",
          canBleach: true,
          estimatedDeliveryDate: DateTime.now().add(const Duration(days: 5)),
        ),
      ],
    ),
    TailorOrder(
      id: "T-ORD-1121",
      customerName: "Farhana Islam",
      customerPhone: "+8801912345678",
      totalAmount: 1800,
      orderDate: DateTime.now().subtract(const Duration(days: 4)),
      status: TailorOrderStatus.inProgress,
      isCompleted: false,
      deliveryAddress: "Uttara Sector 4, Dhaka",
      items: [
        TailorOrderItem(
          name: "Cotton Salwar Set",
          quantity: 1,
          imagePath: "assets/images/fab.jpg",
          color: "Light Pink",
          productPrice: 1800,
          servicePrice: 1000,
          measurementRefImages: ["assets/images/ref4.jpg"],
          tailorInstructions: "Follow standard measurement. Add piping to the neckline.",
          estimatedDeliveryDate: DateTime.now().add(const Duration(days: 3)),
        ),
      ],
    ),
    TailorOrder(
      id: "T-ORD-1090",
      customerName: "Nishat Tasnim",
      customerPhone: "+8801512345678",
      totalAmount: 4000,
      orderDate: DateTime.now().subtract(const Duration(days: 65)),
      completionDate: DateTime.now().subtract(const Duration(days: 60)),
      status: TailorOrderStatus.completed,
      isCompleted: true,
      deliveryAddress: "Banani, Dhaka",
      customerReview: "Best tailor experience ever. The fit is top-notch.",
      customerRating: 5.0,
      items: [
        TailorOrderItem(
          name: "Banarasi Silk Lehenga Blouse",
          quantity: 1,
          imagePath: "assets/images/silk.jpg",
          color: "Magenta",
          productPrice: 4000,
          servicePrice: 2500,
          measurementRefImages: ["assets/images/ref1.jpg", "assets/images/ref3.jpg", "assets/images/ref4.jpg"],
          tailorInstructions: "Please make a classic lehenga blouse with a high neck.",
          canWash: false,
          canDryClean: true,
          ironLevel: "Low",
          estimatedDeliveryDate: DateTime.now().subtract(const Duration(days: 60)),
        ),
      ],
    ),
  ];
  */

  DateTime get _startDate {
    final today = DateTime.now();
    switch (_filterPreset) {
      case OrderFilterPreset.last3Months:
        return DateTime(today.year, today.month - 3, today.day);
      case OrderFilterPreset.last6Months:
        return DateTime(today.year, today.month - 6, today.day);
      case OrderFilterPreset.custom:
        return _customStartDate ?? DateTime(today.year, today.month - 3, today.day);
    }
  }

  DateTime get _endDate {
    final today = DateTime.now();
    if (_filterPreset == OrderFilterPreset.custom && _customEndDate != null) {
      return _customEndDate!;
    }
    return DateTime(today.year, today.month, today.day, 23, 59, 59);
  }

  List<TailorOrder> get _filteredOrders {
    return _orders.where((order) {
      final date = order.orderDate;
      final matchesDate = !date.isBefore(_startDate) && !date.isAfter(_endDate);
      final matchesStatus = _selectedStatus == "All" || _getStatusText(order.status) == _selectedStatus;
      return matchesDate && matchesStatus;
    }).where((order) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final matchesId = order.id.toLowerCase().contains(query);
      final matchesCustomer = order.customerName.toLowerCase().contains(query);
      final matchesProduct = order.items.any((i) => i.name.toLowerCase().contains(query));
      return matchesId || matchesCustomer || matchesProduct;
    }).toList();
  }

  List<TailorOrder> get _pendingOrders => _filteredOrders.where((o) => o.status == TailorOrderStatus.pending || o.status == TailorOrderStatus.confirmed).toList();
  List<TailorOrder> get _currentWorkOrders => _filteredOrders.where((o) => o.status == TailorOrderStatus.inProgress || o.status == TailorOrderStatus.ready).toList();
  List<TailorOrder> get _completedOrders => _filteredOrders.where((o) => o.isCompleted || o.status == TailorOrderStatus.completed).toList();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.08 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ListView(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tailoring Orders",
                          style: TextStyle(
                            fontSize: screenWidth > 400 ? 30 : 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showFilterSheet,
                        icon: Icon(Icons.filter_list, color: primaryGreen),
                        tooltip: "Filter orders",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSearchAndFilter(),
                  const SizedBox(height: 20),
                  _buildMaxOrderButton(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _sectionToggle(
                          label: "Pending",
                          isSelected: _selectedTabIndex == 0,
                          count: _pendingOrders.length,
                          onTap: () => setState(() {
                            _selectedTabIndex = 0;
                            _selectedStatus = "All";
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sectionToggle(
                          label: "Ongoing",
                          isSelected: _selectedTabIndex == 1,
                          count: _currentWorkOrders.length,
                          onTap: () => setState(() {
                            _selectedTabIndex = 1;
                            _selectedStatus = "All";
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sectionToggle(
                          label: "Completed",
                          isSelected: _selectedTabIndex == 2,
                          count: _completedOrders.length,
                          onTap: () => setState(() {
                            _selectedTabIndex = 2;
                            _selectedStatus = "All";
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_selectedTabIndex == 0)
                    _ordersSection(
                      title: "New Requests",
                      icon: Icons.pending_actions,
                      orders: _pendingOrders,
                      emptyText: "No pending requests",
                    )
                  else if (_selectedTabIndex == 1)
                    _ordersSection(
                      title: "Active Orders",
                      icon: Icons.assignment_outlined,
                      orders: _currentWorkOrders,
                      emptyText: "No active tailoring requests",
                    )
                  else
                    _ordersSection(
                      title: "Finished Work",
                      icon: Icons.task_alt,
                      orders: _completedOrders,
                      emptyText: "No completed orders found",
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
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
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Filter orders", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterPreset = OrderFilterPreset.last3Months;
                          _customStartDate = null;
                          _customEndDate = null;
                          _selectedStatus = "All";
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Reset All"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Date Range", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip("Last 3 months", _filterPreset == OrderFilterPreset.last3Months, () {
                      setSheetState(() => _filterPreset = OrderFilterPreset.last3Months);
                      setState(() => _filterPreset = OrderFilterPreset.last3Months);
                    }),
                    _filterChip("Last 6 months", _filterPreset == OrderFilterPreset.last6Months, () {
                      setSheetState(() => _filterPreset = OrderFilterPreset.last6Months);
                      setState(() => _filterPreset = OrderFilterPreset.last6Months);
                    }),
                    _filterChip(
                      _filterPreset == OrderFilterPreset.custom && _customStartDate != null
                          ? "${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}"
                          : "Custom Range",
                      _filterPreset == OrderFilterPreset.custom,
                      () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (range != null) {
                          setSheetState(() {
                            _filterPreset = OrderFilterPreset.custom;
                            _customStartDate = range.start;
                            _customEndDate = range.end.add(const Duration(hours: 23, minutes: 59));
                          });
                          setState(() {
                            _filterPreset = OrderFilterPreset.custom;
                            _customStartDate = range.start;
                            _customEndDate = range.end.add(const Duration(hours: 23, minutes: 59));
                          });
                        }
                      },
                      icon: Icons.calendar_month,
                    ),
                  ],
                ),
                if (_selectedTabIndex == 0) ...[
                  const SizedBox(height: 24),
                  const Text("Status", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ["All", "New Request", "Pending Customer"].map((status) {
                      return _filterChip(status, _selectedStatus == status, () {
                        setSheetState(() => _selectedStatus = status);
                        setState(() => _selectedStatus = status);
                      });
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionToggle({required String label, required bool isSelected, required int count, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? primaryGreen : Colors.green.shade100, width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.w900)),
            Text("$count orders", style: TextStyle(color: isSelected ? Colors.white70 : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _ordersSection({required String title, required IconData icon, required List<TailorOrder> orders, required String emptyText}) {
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
            if (_selectedTabIndex == 2) ...[
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TailorReviewsScreen(tailorName: _tailor.name)),
                  );
                },
                icon: const Icon(Icons.star_outline, size: 16),
                label: const Text("See Reviews"),
                style: TextButton.styleFrom(
                  foregroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _emptyOrdersCard(emptyText)
        else
          ...orders.map((o) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _orderCard(o))),
      ],
    );
  }

  Widget _emptyOrdersCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
    );
  }

  Widget _orderCard(TailorOrder order) {
    if (order.items.isEmpty) {
      return const SizedBox.shrink(); // Hide corrupted or empty orders
    }
    final statusColor = _getStatusColor(order.status);
    final firstItem = order.items.first;

    return GestureDetector(
      onTap: () => _showOrderDetail(order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildProductImage(firstItem.imagePath, 52, 52),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderId.startsWith('ORD-') ? order.orderId : "ORD-${order.orderId}",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      Text("Customer: ${order.customerName}", style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text("Phone: ${order.customerPhone}", style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                      child: Text(_getStatusText(order.status), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                    if (order.status == TailorOrderStatus.inProgress)
                      TextButton(
                        onPressed: () => _showStatusUpdateSheet(order),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 20),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Update Status",
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
                _orderInfo(Icons.shopping_bag_outlined, "${order.totalQuantity} Items"),
                const SizedBox(width: 10),
                _orderInfo(Icons.calendar_today_outlined, _formatDate(order.orderDate)),
                const Spacer(),
                if (order.status != TailorOrderStatus.pending)
                  Text("Tk ${order.totalServicePrice.toInt()}", style: TextStyle(color: Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateSheet(TailorOrder order) {
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
                "Update Work Progress",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (order.status == TailorOrderStatus.pending) ...[
                _statusOptionTile(
                  "Accept Request",
                  Icons.check_circle_outline,
                  primaryGreen,
                  () async {
                    try {
                      await _orderService.updateTailorJobStatus(order.id, TailorJobStatus.confirmed);
                      Navigator.pop(context);
                      _showBanner("Request accepted", isError: false);
                    } catch (e) {
                      _showBanner("Error: $e");
                    }
                  },
                ),
                _statusOptionTile(
                  "Decline Request",
                  Icons.cancel_outlined,
                  Colors.red,
                  () {
                    _showCancellationDialog(order, context, () => Navigator.pop(context));
                  },
                ),
              ],
              if (order.status == TailorOrderStatus.confirmed)
                _statusOptionTile(
                  "Start Stitching",
                  Icons.play_arrow_outlined,
                  Colors.purple,
                  () async {
                    try {
                      await _orderService.updateWorkProgress(order.id, "in_progress");
                      Navigator.pop(context);
                      _showBanner("Stitching started", isError: false);
                    } catch (e) {
                      _showBanner("Error: $e");
                    }
                  },
                ),
              if (order.status == TailorOrderStatus.inProgress)
                _statusOptionTile(
                  "Mark as Finished",
                  Icons.check_circle_outline,
                  primaryGreen,
                  () async {
                    try {
                      await _orderService.updateWorkProgress(order.id, "completed");
                      Navigator.pop(context);
                      _showBanner("Work marked as completed", isError: false);
                    } catch (e) {
                      _showBanner("Error: $e");
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusOptionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _orderInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _showOrderDetail(TailorOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (stfContext, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Stitching Details", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(
                          "ID: ${order.orderId.startsWith('ORD-') ? order.orderId : "ORD-${order.orderId}"}",
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    _infoBadge(
                      _getStatusText(order.status),
                      _getStatusColor(order.status).withValues(alpha: 0.1),
                      _getStatusColor(order.status),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                if (order.status == TailorOrderStatus.pending) _buildActionButtons(order, setModalState, modalContext),
                const SizedBox(height: 20),
                const Text("Customer Requirements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...order.items.map((item) => _itemPreviewCard(order, item, setModalState)),
                const SizedBox(height: 30),
                const Text("Job Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _detailRow("Customer", order.customerName),
                if (order.status != TailorOrderStatus.pending) ...[
                  _detailRow("Stitching Earnings", "Tk ${order.totalServicePrice.toInt()}"),
                  _detailRow(
                    "Expected Delivery",
                    order.items.first.estimatedDeliveryDate != null ? _formatDate(order.items.first.estimatedDeliveryDate!) : "TBD",
                  ),
                ],
                _detailRow("Items to Stitch", "${order.totalQuantity} units"),
                _detailRow("Request Date", _formatDate(order.orderDate)),
                if (order.completionDate != null) _detailRow("Completed On", _formatDate(order.completionDate!)),
                const SizedBox(height: 20),
                const Text("Customer Location", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
           ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: primaryGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.deliveryAddress,
                              style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(order.deliveryAddress)}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, size: 15, color: primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              'Open in Maps',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.isCompleted && order.customerReview != null) ...[
                  const SizedBox(height: 35),
                  const Text("Customer Feedback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _reviewCard(order),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(TailorOrder order, StateSetter setModalState, BuildContext modalContext) {
    final bool canAccept = order.items.every((i) => i.servicePrice > 0 && i.estimatedDeliveryDate != null);

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: canAccept ? () async {
              try {
                final firstItem = order.items.first;
                await _orderService.acceptTailorJob(
                  order.id, 
                  firstItem.servicePrice, 
                  firstItem.estimatedDeliveryDate!,
                );
                Navigator.pop(modalContext);
                _showBanner("Job Accepted Successfully!", isError: false);
              } catch (e) {
                _showBanner("Error: $e");
              }
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Opacity(
              opacity: canAccept ? 1.0 : 0.5,
              child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _showCancellationDialog(order, modalContext, () => Navigator.pop(modalContext));
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Decline", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _itemPreviewCard(TailorOrder order, TailorOrderItem item, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildProductImage(item.imagePath, 60, 60),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Qty: ${item.quantity} | Color: ${item.color}", style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              Text("Tk ${item.productPrice.toInt()}", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Care Instructions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _careTag(Icons.wash, "Wash", item.canWash),
              _careTag(Icons.biotech, "Bleach", item.canBleach),
              _careTag(Icons.dry_cleaning, "Dry Clean", item.canDryClean),
              _careTag(Icons.iron, "Iron: ${item.ironLevel}", true),
            ]),
          ),
          if (order.status == TailorOrderStatus.pending) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("Set Price and Date", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Stitching Price (Tk)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                      const SizedBox(height: 6),
                      TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "e.g. 1500",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            item.servicePrice = double.tryParse(val) ?? 0;
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Est. Delivery Date", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setModalState(() {
                              item.estimatedDeliveryDate = date;
                            });
                            setState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                item.estimatedDeliveryDate != null ? _formatDate(item.estimatedDeliveryDate!) : "Select Date",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Price", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text("Tk ${item.servicePrice.toInt()}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        if (order.status == TailorOrderStatus.inProgress || order.status == TailorOrderStatus.confirmed) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showPriceEditDialog(order, item, setModalState),
                            child: Icon(Icons.edit, size: 14, color: primaryGreen),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Est. Delivery Date", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.estimatedDeliveryDate != null ? _formatDate(item.estimatedDeliveryDate!) : "Not set",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        if (order.status == TailorOrderStatus.inProgress || order.status == TailorOrderStatus.confirmed) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: item.estimatedDeliveryDate ?? DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setModalState(() {
                                  item.estimatedDeliveryDate = date;
                                });
                                setState(() {});
                              }
                            },
                            child: Icon(Icons.edit_calendar_outlined, size: 16, color: primaryGreen),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text("Stitching Instructions & Ref", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          if (item.measurementRefImages != null && item.measurementRefImages!.isNotEmpty) ...[
            const Text(
              "Reference Images:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: item.measurementRefImages!.length,
              itemBuilder: (context, index) {
                final imgPath = item.measurementRefImages![index];
                return GestureDetector(
                  onTap: () => _showFullScreenImage(imgPath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildProductImage(imgPath, 100, 100),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Client Instructions:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(item.tailorInstructions ?? "No specific instructions provided.", style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showMeasurements(order.measurement),
                icon: const Icon(Icons.straighten, size: 14),
                label: const Text("View Customer Measurements", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: primaryGreen, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCancellationDialog(TailorOrder order, BuildContext context, [VoidCallback? onDone]) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reason for Cancellation", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Please tell us why you're declining this request. This feedback helps customers understand.", style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 20),
              const Text("Quick Reasons:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  "Unable to work with selected material",
                  "Order requirements are unclear",
                  "Delivery location issue"
                ].map((reason) => GestureDetector(
                  onTap: () {
                    controller.text = reason;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      reason,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Write reason here...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                ),
              ),
            ],
          ),
        ),


        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      _showBanner("Please provide a reason", isError: true);
                      return;
                    }
                    setState(() {
                      order.status = TailorOrderStatus.cancelled;
                    });
                    _orderService.declineTailorJob(order.id, controller.text.trim()).then((_) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      _showBanner("Request declined successfully.", isError: false);
                      if (onDone != null) onDone();
                    }).catchError((e) {
                      _showBanner("Error: $e");
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC3333),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF8B0000), width: 1.5),
                    ),
                  ),
                  child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPriceEditDialog(TailorOrder order, TailorOrderItem item, StateSetter setModalState) {
    final controller = TextEditingController(text: item.servicePrice > 0 ? item.servicePrice.toInt().toString() : "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Stitching Price", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Price (Tk)",
            hintText: "e.g. 1500",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(controller.text) ?? item.servicePrice;
              try {
                if (order.status != TailorOrderStatus.pending) {
                  await _orderService.editStitchingTerms(
                    order.id,
                    newPrice, 
                    item.estimatedDeliveryDate ?? DateTime.now(),
                  );
                }
                setModalState(() {
                  item.servicePrice = newPrice;
                });
                setState(() {});
                Navigator.pop(context);
                _showBanner("Price updated", isError: false);
              } catch (e) {
                _showBanner("Error: $e");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMeasurements(Measurement? measurement) {
    if (measurement == null) {
      _showBanner("No measurement data available for this customer.");
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const Text("Customer Measurements", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Precision measurements provided by the customer.", style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _measurementTile("Upper Bust", measurement.upperBustCircumference),
                  _measurementTile("Bust", measurement.bustCircumference),
                  _measurementTile("Under Bust", measurement.underBustCircumference),
                  _measurementTile("Round Shoulder", measurement.roundShoulderCircumference),
                  _measurementTile("Waist", measurement.waist),
                  _measurementTile("Hips", measurement.hipsCircumference),
                  _measurementTile("Shoulder to Knee", measurement.shoulderToKnee),
                  _measurementTile("Shoulder to Under Bust", measurement.shoulderToUnderBust),
                  _measurementTile("Shoulder to Bust", measurement.shoulderToBust),
                  _measurementTile("Thigh", measurement.thigh),
                  _measurementTile("Knee", measurement.knee),
                  _measurementTile("Ankle", measurement.ankle),
                  _measurementTile("Waist to Ankle", measurement.waistToAnkle),
                  _measurementTile("Shoulder to Ankle", measurement.shoulderToAnkle),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _measurementTile(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
            child: Text("$value in", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(TailorOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.blue.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ...List.generate(5, (index) => Icon(index < (order.customerRating ?? 0).floor() ? Icons.star : Icons.star_border, color: Colors.blue.shade800, size: 20)),
          const SizedBox(width: 8),
          Text(order.customerRating?.toString() ?? "0.0", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
        const SizedBox(height: 10),
        Text("\"${order.customerReview}\"", style: TextStyle(color: Colors.blue.shade900, fontSize: 14, fontStyle: FontStyle.italic, height: 1.4, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _careTag(IconData icon, String label, bool isOk) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isOk ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(icon, size: 12, color: isOk ? Colors.green.shade700 : Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOk ? Colors.green.shade800 : Colors.grey)),
      ]),
    );
  }

  Widget _infoBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  String _getStatusText(TailorOrderStatus status) {
    switch (status) {
      case TailorOrderStatus.pending: return "New Request";
      case TailorOrderStatus.confirmed: return "Pending Customer";
      case TailorOrderStatus.inProgress: return "In Progress";
      case TailorOrderStatus.ready: return "Ready";
      case TailorOrderStatus.completed: return "Finished";
      case TailorOrderStatus.cancelled: return "Declined";
    }
  }

  Color _getStatusColor(TailorOrderStatus status) {
    switch (status) {
      case TailorOrderStatus.pending: return Colors.orange;
      case TailorOrderStatus.confirmed: return Colors.blue;
      case TailorOrderStatus.inProgress: return Colors.purple;
      case TailorOrderStatus.ready: return Colors.teal;
      case TailorOrderStatus.completed: return primaryGreen;
      case TailorOrderStatus.cancelled: return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  Widget _buildProductImage(String path, double width, double height) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _imagePlaceholder(width, height),
      );
    } else if (path.isNotEmpty) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _imagePlaceholder(width, height),
      );
    } else {
      return _imagePlaceholder(width, height);
    }
  }

  Widget _imagePlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.green.shade50,
      child: Icon(Icons.content_cut, color: primaryGreen),
    );
  }

  // Added Max Order Info and Update Button
  Widget _buildMaxOrderButton() {
    final int? maxOrder = _tailor.maxOrder;
    final String value = maxOrder == null ? "Not Set" : "$maxOrder";
    
    return InkWell(
      onTap: _showMaxOrderDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade100, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bolt_rounded, size: 20, color: primaryGreen),
            ),
            const SizedBox(width: 12),
            const Text(
              "Maximum Order Capacity:",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: primaryGreen,
              ),
            ),
            const Spacer(),
            Text(
              maxOrder == null ? "Set" : "Update",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: primaryGreen,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: primaryGreen),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: _buildProductImage(imagePath, double.infinity, double.infinity),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white, size: 30),
                onPressed: () {
                  _showBanner("Reference image download started...", isError: false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaxOrderDialog() {
    final controller = TextEditingController(
      text: _tailor.maxOrder?.toString() ?? "",
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Set Maximum Orders",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Set the maximum number of orders you can handle. Leave empty for unlimited orders.",
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter amount (e.g. 10)",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              final newMaxOrder = val.isEmpty ? null : int.tryParse(val);
              
              if (newMaxOrder == _tailor.maxOrder) {
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);

              setState(() {
                _tailor = _tailor.copyWith(maxOrder: newMaxOrder);
              });

              final uid = UserSession.instance.uid;
              if (uid != null) {
                try {
                  await _tailorService.updateTailorProfile(uid, {'maxOrder': newMaxOrder});
                  _showBanner("Capacity updated successfully!", isError: false);
                } catch (e) {
                  debugPrint("Error updating maximum order: $e");
                  _showBanner("Failed to update server: $e", isError: true);
                }
              } else {
                _showBanner("Local capacity updated (Not logged in)", isError: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Save",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
