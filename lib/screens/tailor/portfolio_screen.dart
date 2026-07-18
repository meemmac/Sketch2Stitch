import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─── Model ───────────────────────────────────────────────────────────────
///
/// Mirrors the backend `Portfolio` model (id, tailorId, image, description).
/// `image` will eventually hold a backend URL; for now, while the frontend
/// is built ahead of the API, it holds a local path (asset or file) and
/// `isAsset` (a frontend-only, non-persisted-to-backend flag) tells the UI
/// how to render it. Swapping to network images later just means changing
/// `_buildItemImage`/`_buildItemImageLarge` to use `Image.network(image)`.
class Portfolio {
  final String id;
  final String tailorId;
  String? image;
  String? description;
  bool isAsset;

  Portfolio({
    required this.id,
    required this.tailorId,
    this.image,
    this.description,
    this.isAsset = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'tailorId': tailorId,
    'image': image,
    'description': description,
    'isAsset': isAsset,
  };

  factory Portfolio.fromMap(Map<String, dynamic> map) {
    return Portfolio(
      id: map['id'] as String? ?? '',
      tailorId: map['tailorId'] as String? ?? '',
      image: map['image'] as String?,
      description: map['description'] as String?,
      isAsset: map['isAsset'] as bool? ?? false,
    );
  }
}

/// ─── Portfolio Screen ───────────────────────────────────────────────────

class TailorPortfolioScreen extends StatefulWidget {
  const TailorPortfolioScreen({super.key});

  @override
  State<TailorPortfolioScreen> createState() => _TailorPortfolioScreenState();
}

class _TailorPortfolioScreenState extends State<TailorPortfolioScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const String _cacheKey = 'tailor_portfolio_cache_v1';

  String _searchQuery = "";
  int _gridAnimationSeed = 0;
  final List<Portfolio> items = <Portfolio>[];

  // TODO: replace with the signed-in tailor's real id once auth is wired up.
  static const String _currentTailorId = "tailor_demo";

  String _generateId() =>
      "port_${DateTime.now().millisecondsSinceEpoch}_${items.length}";

  List<Portfolio> _seedItems() {
    return <Portfolio>[
      Portfolio(
        id: "port_seed_1",
        tailorId: _currentTailorId,
        description:
            "Custom bridal gown crafted from imported silk with hand-embroidered detailing along the bodice and train.",
        image: 'assets/images/saree.jpg',
        isAsset: true,
      ),
      Portfolio(
        id: "port_seed_2",
        tailorId: _currentTailorId,
        description:
            "Modern fitted denim jacket with reinforced stitching and a relaxed collar, made to measure for everyday wear.",
        image: 'assets/images/fab.jpg',
        isAsset: true,
      ),
      Portfolio(
        id: "port_seed_3",
        tailorId: _currentTailorId,
        description:
            "Lightweight linen two-piece suit designed for warm-weather formal occasions, fully lined for a clean drape.",
        image: 'assets/images/fab2.jpg',
        isAsset: true,
      ),
    ];
  }

  List<Portfolio> get _filteredItems {
    final query = _searchQuery.toLowerCase();
    return items.where((item) {
      return (item.description ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(_seedItems());
      });
      await _savePortfolio();
      return;
    }

    final decoded = jsonDecode(raw);
    final loaded = decoded is List
        ? decoded
              .whereType<Map>()
              .map(
                (entry) =>
                    Portfolio.fromMap(Map<String, dynamic>.from(entry)),
              )
              .toList()
        : _seedItems();

    if (!mounted) return;
    setState(() {
      items
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _savePortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }

  void _animateToNewestItem() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
  }

  void _openDetails(Portfolio item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortfolioDetailsScreen(item: item),
      ),
    );
  }

  Future<void> _showPortfolioForm({Portfolio? item}) async {
    final desc = TextEditingController(text: item?.description ?? "");
    String imagePath = item?.image ?? "";
    bool isAsset = item?.isAsset ?? false;
    bool showValidationError = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (c, setM) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.25,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      item == null ? "Add Portfolio Item" : "Edit Portfolio Item",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Image Picker
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null) {
                            setM(() {
                              imagePath = image.path;
                              isAsset = false;
                              showValidationError = false;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: showValidationError && imagePath.isEmpty
                                  ? Colors.red
                                  : Colors.green.shade100,
                            ),
                          ),
                          child: imagePath.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 32,
                                      color: Colors.green.shade800,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Tap to add cover image",
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: isAsset
                                      ? Image.asset(imagePath, fit: BoxFit.cover)
                                      : Image.file(
                                          File(imagePath),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: desc,
                      maxLines: 4,
                      onChanged: (_) => setM(() => showValidationError = false),
                      decoration: InputDecoration(
                        labelText: "Description",
                        alignLabelWithHint: true,
                        errorText:
                            showValidationError && desc.text.trim().isEmpty
                            ? "Description is required"
                            : null,
                      ),
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          if (imagePath.isEmpty || desc.text.trim().isEmpty) {
                            setM(() => showValidationError = true);
                            return;
                          }

                          setState(() {
                            if (item == null) {
                              items.add(
                                Portfolio(
                                  id: _generateId(),
                                  tailorId: _currentTailorId,
                                  description: desc.text.trim(),
                                  image: imagePath,
                                  isAsset: isAsset,
                                ),
                              );
                            } else {
                              item.description = desc.text.trim();
                              item.image = imagePath;
                              item.isAsset = isAsset;
                            }
                            _gridAnimationSeed++;
                          });
                          await _savePortfolio();
                          if (item == null) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _animateToNewestItem(),
                            );
                          }
                          if (!mounted) return;
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          item == null ? "Add Item" : "Save Changes",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteItem(Portfolio item) async {
    setState(() {
      items.remove(item);
      _gridAnimationSeed++;
    });
    await _savePortfolio();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text(
          "Tailor Portfolio",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPortfolioForm(),
        backgroundColor: Colors.green.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Portfolio",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: _portfolioSummary(items.length),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Search your portfolio...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? "No portfolio items yet"
                            : "No items match your search",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            mainAxisSpacing: 15,
                            crossAxisSpacing: 15,
                          ),
                      itemCount: filteredItems.length,
                      itemBuilder: (c, i) {
                        return _buildAnimatedGridCard(filteredItems[i], i);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedGridCard(Portfolio item, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${item.id}-$_gridAnimationSeed-$index'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
          ),
        );
      },
      child: _buildPortfolioCard(item),
    );
  }

  Widget _buildPortfolioCard(Portfolio item) {
    return GestureDetector(
      onTap: () => _openDetails(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildItemImage(item),
                  Positioned(
                    top: 8,
                    right: 8,
                    left: 8,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _actionBtn(
                              Icons.edit,
                              Colors.blue,
                              () => _showPortfolioForm(item: item),
                            ),
                            const SizedBox(width: 5),
                            _actionBtn(
                              Icons.delete,
                              Colors.red,
                              () => _deleteItem(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                (item.description ?? '').isEmpty
                    ? "No description"
                    : item.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(Portfolio item) {
    final path = item.image ?? '';
    if (path.isEmpty) {
      return Container(
        color: Colors.green.shade50,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.green.shade200,
        ),
      );
    }
    // NOTE: once the backend is wired up, `image` will hold a URL and this
    // should switch to Image.network(path, fit: BoxFit.cover).
    return item.isAsset
        ? Image.asset(path, fit: BoxFit.cover)
        : Image.file(File(path), fit: BoxFit.cover);
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _portfolioSummary(int itemCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.design_services_outlined,
            size: 18,
            color: Colors.green.shade800,
          ),
          const SizedBox(width: 8),
          Text(
            "$itemCount",
            style: TextStyle(
              color: Colors.green.shade900,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              "portfolio pieces showcased",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Portfolio Details Screen ──────────────────────────────────────────

class PortfolioDetailsScreen extends StatelessWidget {
  final Portfolio item;

  const PortfolioDetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final imagePath = item.image ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text(
          "Portfolio Item",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: double.infinity,
                height: 320,
                child: imagePath.isEmpty
                    ? Container(
                        color: Colors.green.shade50,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.green.shade200,
                          size: 48,
                        ),
                      )
                    // NOTE: swap to Image.network(imagePath, fit: BoxFit.cover)
                    // once the backend serves real image URLs.
                    : (item.isAsset
                          ? Image.asset(imagePath, fit: BoxFit.cover)
                          : Image.file(File(imagePath), fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Description",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              (item.description ?? '').isEmpty
                  ? "No description provided."
                  : item.description!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}