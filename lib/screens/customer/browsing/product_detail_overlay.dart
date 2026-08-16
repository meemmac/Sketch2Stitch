import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/favorite.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/cart_service.dart';
import 'package:sketch2stitch/services/user_session.dart';
import '../../../widgets/video_preview_player.dart';
import '../../../widgets/care_info_tooltip.dart';
import '../../../widgets/top_feedback_banner.dart';

class ProductDetailOverlay extends StatefulWidget {
  final Product product;
  final bool isFabric;
  final String retailerName;
  final List<String>? materialBlends;
  final UserRole userRole;
  final String? customerId;
  final FavoriteService? favoriteService;

  const ProductDetailOverlay({
    super.key,
    required this.product,
    this.isFabric = true,
    this.retailerName = 'Unknown Retailer',
    this.materialBlends,
    this.userRole = UserRole.customer,
    this.customerId,
    this.favoriteService,
  });

  @override
  State<ProductDetailOverlay> createState() => _ProductDetailOverlayState();
}

class _ProductDetailOverlayState extends State<ProductDetailOverlay> {
  final CartService _cartService = CartService();

  int _quantity = 1;
  late ColorOption? _selectedOption;
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    final options = widget.product.colorOptions;
    _selectedOption = options.isEmpty
        ? null
        : options.firstWhere((o) => o.stock > 0, orElse: () => options.first);
    
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    if (widget.customerId != null && widget.favoriteService != null) {
      try {
        final isFav = await widget.favoriteService!
            .isFavoriteProduct(widget.customerId!, widget.product.id)
            .first;
        setState(() {
          _isFavorite = isFav;
          _isLoadingFavorite = false;
        });
      } catch (e) {
        setState(() {
          _isLoadingFavorite = false;
        });
      }
    } else {
      setState(() {
        _isLoadingFavorite = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.customerId == null || widget.favoriteService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add favorites'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await widget.favoriteService!
          .toggleFavoriteProduct(widget.customerId!, widget.product.id);
      setState(() {
        _isFavorite = !_isFavorite;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
          backgroundColor: _isFavorite ? const Color(0xFF4E8B6F) : Colors.grey,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _inStock => (_selectedOption?.stock ?? 0) > 0;
  bool get _isCustomer => widget.userRole == UserRole.customer;

  String get _materialBlendDisplay {
    if (widget.materialBlends != null && widget.materialBlends!.isNotEmpty) {
      return widget.materialBlends!.join(", ");
    }

    // Use materialType list from Product model
    if (widget.product.materialType.isNotEmpty) {
      final parts = widget.product.materialType.map((m) {
        if (m.blend > 0) {
          return '${m.blend.toInt()}% ${m.type}';
        }
        return m.type;
      }).toList();
      return parts.join(", ");
    }
    
    return "N/A";
  }

  void _selectOption(ColorOption option) {
    setState(() {
      _selectedOption = option;
      _quantity = 1;
    });
  }

  /// Persists the chosen colour option + quantity to the customer's
  /// `Cart-Items`. The service merges with an existing line for the same
  /// product/option and rejects anything beyond available stock.
  Future<void> _addToCart() async {
    final option = _selectedOption;
    if (option == null) return;

    final customerId = UserSession.instance.uid;
    if (customerId == null || customerId.isEmpty) {
      _showSnack('Please sign in to add items to your cart.', isError: true);
      return;
    }

    // Captured up front: the confirmation banner is shown after this
    // sheet has been popped, so `context` is no longer usable by then.
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context);

    setState(() => _isAddingToCart = true);
    try {
      await _cartService.addToCart(
        customerId,
        widget.product.id,
        option.optionId,
        _quantity,
      );
      navigator.pop();
      _showSnack('Added to cart!', overlay: overlay);
    } catch (e) {
      _showSnack(
        e is CartServiceException ? e.message : 'Could not add to cart.',
        isError: true,
        overlay: overlay,
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _showSnack(
    String message, {
    bool isError = false,
    OverlayState? overlay,
  }) {
    final target = overlay ?? Overlay.maybeOf(context, rootOverlay: true);
    if (target == null) return;
    AppFeedback.showInOverlay(target, message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final bool isElement = !widget.isFabric;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final materialBlendDisplay = _materialBlendDisplay;
    
    // Check if careSymbol exists and is not empty
    final bool hasCareInstructions = widget.product.careSymbol.isNotEmpty;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          if (widget.product.colorOptions.every((o) => o.stock <= 0))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.shade800,
              child: const Text(
                "Sorry, currently unavailable",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductImage(),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.productName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (_isCustomer)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: Icon(
                              _isLoadingFavorite 
                                  ? Icons.favorite_border 
                                  : (_isFavorite ? Icons.favorite : Icons.favorite_border),
                              color: _isLoadingFavorite 
                                  ? Colors.grey 
                                  : (_isFavorite ? Colors.red : Colors.grey),
                              size: 28,
                            ),
                            onPressed: _isLoadingFavorite ? null : _toggleFavorite,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        _selectedOption != null
                            ? 'Tk ${_selectedOption!.price.toStringAsFixed(0)}'
                            : widget.product.priceRange,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C5C44),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_bike, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Tk 50 delivery',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (!_inStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red[700]),
                              const SizedBox(width: 3),
                              Text(
                                'Out of Stock',
                                style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      else if (_selectedOption != null && _selectedOption!.stock <= 5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory, size: 12, color: Colors.orange[700]),
                              const SizedBox(width: 3),
                              Text(
                                'Only ${_selectedOption!.stock} left',
                                style: TextStyle(fontSize: 10, color: Colors.orange[800], fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                              const SizedBox(width: 3),
                              Text(
                                'In Stock',
                                style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.store,
                        color: Color(0xFF2C5C44),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.retailerName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Only show material blend for fabrics
                  if (widget.isFabric && materialBlendDisplay != "N/A") ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[100]!),
                      ),
                      child: Text(
                        materialBlendDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C5C44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isCustomer) ...[
                    Text(
                      isElement ? 'Quantity (piece)' : 'Quantity (gauge)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: !_inStock
                                ? null
                                : () {
                                    setState(() {
                                      if (_quantity > 1) _quantity--;
                                    });
                                  },
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          ),
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: !_inStock
                                ? null
                                : () {
                                    setState(() {
                                      final maxStock = _selectedOption?.stock ?? 1;
                                      if (_quantity < maxStock) _quantity++;
                                    });
                                  },
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Available Colors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.product.colorOptions.map((option) {
                      final isSelected = _selectedOption?.optionId == option.optionId;
                      final isOutOfStock = option.stock <= 0;
                      return GestureDetector(
                        onTap: () => _selectOption(option),
                        child: Opacity(
                          opacity: isOutOfStock ? 0.5 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2C5C44)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2C5C44)
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  option.color,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  isOutOfStock
                                      ? 'Out of stock'
                                      : 'Tk ${option.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.85)
                                        : const Color.fromARGB(255, 59, 59, 59),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!isOutOfStock) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inventory_2,
                                        size: 12,
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.grey[500],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${option.stock} ${isElement ? 'pcs' : 'units'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.white.withOpacity(0.7)
                                              : const Color.fromARGB(255, 63, 63, 63),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Only show Care Instructions for Fabrics that have them
                  if (widget.isFabric && hasCareInstructions) ...[
                    const SizedBox(height: 25),
                    const Text(
                      "Care Instructions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          CareInstructionRow(
                            label: "Machine Washable",
                            isOk: _canMachineWash(),
                            info: "Indicates whether the garment can be safely washed in a washing machine and the recommended washing conditions. Following these instructions helps maintain the fabric's quality, color, and shape.",
                          ),
                          CareInstructionRow(
                            label: "Bleach Allowed",
                            isOk: _canBleach(),
                            info: "Indicates whether bleach can be safely used on the fabric. Some materials may fade, weaken, or become damaged when exposed to bleach.",
                          ),
                          CareInstructionRow(
                            label: "Dry Clean Only",
                            isOk: _canDryClean(),
                            info: "Indicates whether the garment should be professionally cleaned using special solvents instead of water. This method is recommended for delicate fabrics or garments with special finishes.",
                          ),
                          CareInstructionRow(
                            label: "Tumble Dry",
                            isOk: _canTumbleDry(),
                            info: "Tumble drying is the process of drying clothes in a clothes dryer (dryer machine) instead of hanging them to air dry. It indicates whether the garment is suitable for tumble drying and the recommended heat setting. Using the wrong drying method may cause shrinking or fabric damage.",
                          ),
                          CareInstructionRow(
                            label: "Iron Level",
                            isOk: true,
                            value: _getIronLevel(),
                            info: "Indicates the maximum ironing temperature that is safe for the fabric. Using excessive heat may damage, shrink, or burn the material.",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Product Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_isCustomer)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            !_inStock || _isAddingToCart ? null : _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C5C44),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isAddingToCart
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    final imageUrl = _selectedOption != null && _selectedOption!.image.isNotEmpty ? _selectedOption!.image.first : null;
    final videoUrl = _selectedOption != null && _selectedOption!.video.isNotEmpty ? _selectedOption!.video.first : null;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.75;
    final imageHeight = 250.0;

    if (_selectedOption != null && _selectedOption!.image.isNotEmpty && _selectedOption!.video.isNotEmpty) {
      return SizedBox(
        height: imageHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            ..._selectedOption!.image.map((img) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: imageHeight,
                  width: imageWidth,
                  color: Colors.grey[200],
                  child: img.startsWith('http')
                      ? Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _imageFallback(),
                        )
                      : Image.asset(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _imageFallback(),
                        ),
                ),
              ),
            )),
            ..._selectedOption!.video.map((vid) {
              final cleanPath = vid.trim().replaceAll("'", "").replaceAll('"', "");
              if (cleanPath.isEmpty) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: VideoPreviewPlayer(
                    videoPath: cleanPath,
                    isAsset: cleanPath.toLowerCase().startsWith('assets/'),
                    height: imageHeight,
                    width: imageWidth,
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: imageHeight,
          width: double.infinity,
          color: Colors.grey[200],
          child: imageUrl.startsWith('http')
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _imageFallback(),
                )
              : Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _imageFallback(),
                ),
        ),
      );
    }
    
    if (videoUrl != null && videoUrl.trim().isNotEmpty) {
      final cleanVideoUrl = videoUrl.trim().replaceAll("'", "").replaceAll('"', "");
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: VideoPreviewPlayer(
          videoPath: cleanVideoUrl,
          isAsset: cleanVideoUrl.toLowerCase().startsWith('assets/'),
          height: imageHeight,
          width: double.infinity,
        ),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: imageHeight,
        width: double.infinity,
        color: Colors.grey[200],
        child: _imageFallback(),
      ),
    );
  }

  Widget _imageFallback() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image_not_supported,
          size: 60,
          color: Colors.grey,
        ),
        const SizedBox(height: 8),
        Text(
          'Image not available',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  bool _canMachineWash() {
    final careSymbols = widget.product.careSymbol.map((s) => s.toLowerCase()).toList();
    return careSymbols.any((s) => s.contains('wash'));
  }

  bool _canBleach() {
    final careSymbols = widget.product.careSymbol.map((s) => s.toLowerCase()).toList();
    return careSymbols.any((s) => s.contains('bleach') && !s.contains('do not') && !s.contains('no'));
  }

  bool _canDryClean() {
    final careSymbols = widget.product.careSymbol.map((s) => s.toLowerCase()).toList();
    return careSymbols.any((s) => s.contains('dry clean'));
  }

  bool _canTumbleDry() {
    final careSymbols = widget.product.careSymbol.map((s) => s.toLowerCase()).toList();
    return careSymbols.any((s) => s.contains('tumble dry'));
  }

  String _getIronLevel() {
    final careSymbols = widget.product.careSymbol.map((s) => s.toLowerCase()).toList();
    if (careSymbols.any((s) => s.contains('iron'))) {
      if (careSymbols.any((s) => s.contains('low'))) return "Low";
      if (careSymbols.any((s) => s.contains('medium'))) return "Medium";
      if (careSymbols.any((s) => s.contains('high'))) return "High";
      return "Medium";
    }
    return "Medium";
  }
}