import 'package:flutter/material.dart';
import '../screens/customer/cart_screen.dart';
import '../services/cart_service.dart';
import '../services/user_session.dart';

/// Cart entry point with a live item-count badge fed by `Cart-Items`.
///
/// The badge shows total units (not lines), so adding 3 metres of one
/// fabric reads as "3" — matching the count shown inside the cart itself.
class CartIconButton extends StatefulWidget {
  const CartIconButton({
    super.key,
    this.iconSize = 28,
    this.color = Colors.black87,
    this.padding,
    this.constraints,
  });

  final double iconSize;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> {
  late final Stream<int> _countStream;

  @override
  void initState() {
    super.initState();
    final uid = UserSession.instance.uid;
    _countStream = uid == null || uid.isEmpty
        ? const Stream<int>.empty()
        : CartService().streamCartCount(uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              icon: Icon(
                Icons.shopping_cart_outlined,
                color: widget.color,
                size: widget.iconSize,
              ),
              padding: widget.padding,
              constraints: widget.constraints,
              tooltip: 'My Cart',
            ),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
