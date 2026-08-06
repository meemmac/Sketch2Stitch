import 'dart:io';
import '../../services/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/portfolio.dart';
import '../../services/portfolio_service.dart';
import '../../services/user_session.dart';

/// ─── Portfolio Screen ───────────────────────────────────────────────────
///
/// Backed by [PortfolioService] (Firestore) + Firebase Storage for images.
/// `image` on [Portfolio] is now always a network URL — the picker still
/// lets the tailor choose a local file, but it's uploaded to Storage before
/// the item is written to Firestore.

class TailorPortfolioScreen extends StatefulWidget {
  const TailorPortfolioScreen({super.key});

  @override
  State<TailorPortfolioScreen> createState() => _TailorPortfolioScreenState();
}

class _TailorPortfolioScreenState extends State<TailorPortfolioScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PortfolioService _service = PortfolioService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  String _searchQuery = "";
  int _gridAnimationSeed = 0;
  final List<Portfolio> items = <Portfolio>[];

  bool _isLoading = true;
  String? _loadError;

  // Falls back to '' if somehow no session is active; every call site below
  // guards against an empty tailorId before hitting Firestore.
  String get _currentTailorId => UserSession.instance.uid ?? '';

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
    final tailorId = _currentTailorId;
    if (tailorId.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = "No signed-in tailor found.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Large-ish page size keeps this simple (no "load more" UI) — bump
      // PortfolioService.defaultPageSize or add pagination here later if a
      // tailor's portfolio regularly exceeds this.
      final result = await _service.getTailorPortfolio(tailorId, pageSize: 100);
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(result.items);
        _isLoading = false;
      });
    } on PortfolioServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.message;
      });
    }
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
      MaterialPageRoute(builder: (_) => PortfolioDetailsScreen(item: item)),
    );
  }

  /// Uploads a locally-picked image to `portfolio/{tailorId}/{filename}` and
  /// returns its download URL.
  /// Uploads a locally-picked image to Cloudinary under `portfolio/{tailorId}`
/// and returns its secure URL. Throws if the upload fails so callers can
/// surface an error instead of silently saving a blank image.
Future<String> _uploadImage(String tailorId, File file) async {
  final url = await _cloudinaryService.uploadImage(
    file,
    folder: 'portfolio/$tailorId',
  );
  if (url == null) {
    throw Exception("Couldn't upload image. Try again.");
  }
  return url;
}

  Future<void> _showPortfolioForm({Portfolio? item}) async {
    final tailorId = _currentTailorId;
    if (tailorId.isEmpty) return;

    final desc = TextEditingController(text: item?.description ?? "");
    // Local-only until saved: either an existing network URL (editing, not
    // replaced) or a path to a freshly-picked file awaiting upload.
    String? existingImageUrl = item?.image;
    File? pickedFile;
    bool showValidationError = false;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (c, setM) {
          final hasImage = pickedFile != null || (existingImageUrl?.isNotEmpty ?? false);

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
                      item == null ? "Add Work Item" : "Edit Work Item",
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
                              pickedFile = File(image.path);
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
                              color: showValidationError && !hasImage
                                  ? Colors.red
                                  : Colors.green.shade100,
                            ),
                          ),
                          child: !hasImage
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
                                  child: pickedFile != null
                                      ? Image.file(pickedFile!, fit: BoxFit.cover)
                                      : Image.network(
                                          existingImageUrl!,
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
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!hasImage || desc.text.trim().isEmpty) {
                                  setM(() => showValidationError = true);
                                  return;
                                }

                                setM(() => isSaving = true);
                                try {
                                  String imageUrl = existingImageUrl ?? '';
                                  if (pickedFile != null) {
                                    imageUrl = await _uploadImage(
                                      tailorId,
                                      pickedFile!,
                                    );
                                  }

                                  if (item == null) {
                                    final created = await _service.addPortfolioItem(
                                      tailorId,
                                      imageUrl,
                                      description: desc.text.trim(),
                                    );
                                    setState(() {
                                      items.add(created);
                                      _gridAnimationSeed++;
                                    });
                                    WidgetsBinding.instance.addPostFrameCallback(
                                      (_) => _animateToNewestItem(),
                                    );
                                  } else {
                                    final updated = await _service.updatePortfolioItem(
                                      item.id,
                                      {
                                        'image': imageUrl,
                                        'description': desc.text.trim(),
                                      },
                                    );
                                    setState(() {
                                      final idx = items.indexWhere((i) => i.id == item.id);
                                      if (idx != -1) items[idx] = updated;
                                      _gridAnimationSeed++;
                                    });
                                  }

                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                } on PortfolioServiceException catch (e) {
                                  setM(() => isSaving = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                } catch (_) {
                                  setM(() => isSaving = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Couldn't upload image. Try again."),
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                item == null ? "Add" : "Save Changes",
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
    // Optimistic delete with rollback so the UI doesn't wait on the network.
    final index = items.indexOf(item);
    setState(() {
      items.remove(item);
      _gridAnimationSeed++;
    });
    try {
      await _service.deletePortfolioItem(item.id);
    } on PortfolioServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        items.insert(index.clamp(0, items.length), item);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
        label: const Text("Add Work", style: TextStyle(color: Colors.white)),
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
            Expanded(child: _buildBody(filteredItems)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Portfolio> filteredItems) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadPortfolio, child: const Text("Retry")),
          ],
        ),
      );
    }
    if (filteredItems.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? "No items yet" : "No items match your search",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (c, i) {
        return _buildAnimatedGridCard(filteredItems[i], i);
      },
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
    final url = item.image ?? '';
    if (url.isEmpty) {
      return Container(
        color: Colors.green.shade50,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.green.shade200,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.green.shade50,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.green.shade50,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.green.shade200,
        ),
      ),
    );
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
    final imageUrl = item.image ?? '';
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
                child: imageUrl.isEmpty
                    ? Container(
                        color: Colors.green.shade50,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.green.shade200,
                          size: 48,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.green.shade50,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.green.shade50,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.green.shade200,
                            size: 48,
                          ),
                        ),
                      ),
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