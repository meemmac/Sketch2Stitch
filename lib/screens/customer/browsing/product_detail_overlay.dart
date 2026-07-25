import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import '../../../widgets/video_preview_player.dart';

class ProductDetailOverlay extends StatefulWidget {
  final Product product;
  final bool isFabric;
  final String retailerName;

  const ProductDetailOverlay({
    super.key,
    required this.product,
    this.isFabric = true,
    this.retailerName = 'Unknown Retailer',
  });

  @override
  State<ProductDetailOverlay> createState() => _ProductDetailOverlayState();
}

class _ProductDetailOverlayState extends State<ProductDetailOverlay> {
  int _quantity = 1;
  late ColorOption? _selectedOption;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    final options = widget.product.colorOptions;
    _selectedOption = options.isEmpty
        ? null
        : options.firstWhere((o) => o.stock > 0, orElse: () => options.first);
  }

  bool get _inStock => (_selectedOption?.stock ?? 0) > 0;

  void _selectOption(ColorOption option) {
    setState(() {
      _selectedOption = option;
      _quantity = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isElement = !widget.isFabric;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    
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
          // Handle bar
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
          // Close button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  _buildProductImage(),
                  const SizedBox(height: 16),

                  // Title and Favorite
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
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          icon: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : Colors.grey,
                            size: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              _isFavorite = !_isFavorite;
                            });
                          },
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

                  // Price / delivery / stock badge — wraps instead of overflowing
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

                  // Retailer Name
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

                  // Material Blend Badge — pill style like the reference design,
                  // shows the blend text from product.dart's materialDisplay
                  if (widget.product.materialDisplay.isNotEmpty && widget.product.materialDisplay != "N/A") ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Text(
                            widget.product.materialDisplay,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C5C44),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quantity - Different label for fabric vs element
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

                  // Available Colors
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
                                        ? Colors.white.withValues(alpha: 0.85)
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
                                            ? Colors.white.withValues(alpha: 0.7)
                                            : Colors.grey[500],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${option.stock} ${isElement ? 'pcs' : 'units'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.7)
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

                  // Care Instructions - Exactly like Inventory Page (5 care levels)
                  if (widget.isFabric) ...[
                    const Text(
                      'Care Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _careInfoRow(Icons.wash, 'Machine Washable', _canMachineWash()),
                          _careInfoRow(Icons.biotech, 'Bleach Allowed', _canBleach()),
                          _careInfoRow(Icons.dry_cleaning, 'Dry Clean Only', _canDryClean()),
                          _careInfoRow(Icons.settings_input_component, 'Tumble Dry', _canTumbleDry()),
                          _careInfoRow(Icons.iron, 'Iron Level', true, trailing: _getIronLevel()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Product Description
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

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: !_inStock
                          ? null
                          : () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Added to cart!'),
                                  backgroundColor: Color(0xFF4E8B6F),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2C5C44),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF2C5C44)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C5C44),
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
    final imageUrl = _selectedOption?.image;
    final videoUrl = _selectedOption?.video;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.75;
    final imageHeight = 250.0;

    if (imageUrl != null && imageUrl.isNotEmpty && videoUrl != null && videoUrl.isNotEmpty) {
      return SizedBox(
        height: imageHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: imageHeight,
                width: imageWidth,
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
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VideoPreviewPlayer(
                videoPath: videoUrl!,
                height: imageHeight,
                width: imageWidth,
              ),
            ),
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
    
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: VideoPreviewPlayer(
          videoPath: videoUrl,
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

  // ─── Care Info Helper Methods for Inventory Style ─────────────────────

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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isOk ? Colors.black87 : Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              trailing ?? (isOk ? "Yes" : "No"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOk ? Colors.green.shade800 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
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