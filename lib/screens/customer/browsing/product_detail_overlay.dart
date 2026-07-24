import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';

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
    // Prefer the first in-stock color option; fall back to the first
    // option at all (even if out of stock) so something is always shown.
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
                  // Product Image (follows the selected color option)
                  _buildProductImage(),
                  const SizedBox(height: 16),

                  // Title and Favorite
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.productName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
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
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Price for the currently selected color option
                  Row(
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
                      const SizedBox(width: 10),
                      if (!_inStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Out of stock',
                            style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600),
                          ),
                        )
                      else if (_selectedOption != null && _selectedOption!.stock <= 5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Only ${_selectedOption!.stock} left',
                            style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w600),
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
                      Text(
                        widget.retailerName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Material Type (from database)
                  Row(
                    children: [
                      const Icon(
                        Icons.category,
                        color: Color(0xFF2C5C44),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.product.materialType,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Blend Option with Material Type
                  Row(
                    children: [
                      const Icon(
                        Icons.blender,
                        color: Color(0xFF2C5C44),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '100% ${widget.product.materialType}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Quantity
                  const Text(
                    'Quantity (gauge)',
                    style: TextStyle(
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Available Colors — each chip is a full ColorOption with
                  // its own price/stock, not just a color name anymore.
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
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2C5C44)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2C5C44)
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option.color,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '100% ${widget.product.materialType}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOutOfStock
                                      ? 'Out of stock'
                                      : 'Tk ${option.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Care Instructions (from database) - Only for fabrics
                  if (widget.isFabric && widget.product.careSymbol.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          color: Color(0xFF2C5C44),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Care Level',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.product.careSymbol.map((care) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF6F0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Color(0xFF2C5C44),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                care,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2C5C44),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Product Description (from database)
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

                  // Action Buttons - Only Add to Cart
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

  // In product_detail_overlay.dart, update _buildProductImage method:

Widget _buildProductImage() {
  final imageUrl = _selectedOption?.image;
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey[200],
      child: imageUrl != null && imageUrl.isNotEmpty
          ? imageUrl.startsWith('http')
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _imageFallback(),
                )
              : Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _imageFallback(),
                )
          : _imageFallback(),
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
}