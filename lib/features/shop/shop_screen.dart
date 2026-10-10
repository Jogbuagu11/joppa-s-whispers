// The Pearl shop: the store's products with the store's own prices.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_app_bar.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF1A1205);

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.shop,
    required this.purchases,
    this.onBuy,
    this.top,
  });

  /// Shown above the store's products (today's deals).
  final Widget? top;

  /// Told which product the player tapped Buy for (analytics).
  final void Function(String productId)? onBuy;

  final PurchaseCoordinator shop;
  final PurchasesController purchases;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final Future<List<StoreProduct>> _products = widget.shop.loadProducts();

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    return Scaffold(
      key: const Key('shop_screen'),
      backgroundColor: _ink,
      appBar: gameAppBar(const Text('Pearl Shop')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListenableBuilder(
                listenable: widget.purchases,
                builder: (context, _) => Text(
                  'You have ${widget.purchases.pearls} Pearls',
                  key: const Key('shop_pearls'),
                  style: const TextStyle(color: _cream, fontSize: 16),
                ),
              ),
            ),
            // Today's deals and the store's products scroll as one.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ?widget.top,
                    FutureBuilder<List<StoreProduct>>(
                      future: _products,
                      builder: (context, snapshot) {
                        final products = snapshot.data;
                        if (products == null) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: _gold),
                          );
                        }
                        if (products.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'The shop is not available right now. '
                              'Please try again later.',
                              key: Key('shop_unavailable'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _cream),
                            ),
                          );
                        }
                        return ListenableBuilder(
                          listenable: Listenable.merge([
                            widget.purchases,
                            shop.busy,
                          ]),
                          builder: (context, _) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                for (final product in products) _tile(product),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: shop.message,
              builder: (context, message, _) => message == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        message,
                        key: const Key('shop_message'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _cream, fontSize: 14),
                      ),
                    ),
            ),
            TextButton(
              key: const Key('shop_restore'),
              onPressed: shop.restore,
              child: const Text(
                'Restore purchases',
                style: TextStyle(color: _gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(StoreProduct product) {
    final shop = widget.shop;
    final owned = !widget.purchases.canBuyProduct(product.id);
    final gives = shop.products[product.id];
    final contents = [
      if ((gives?.pearls ?? 0) > 0) '${gives?.pearls} Pearls',
      if ((gives?.manna ?? 0) > 0) '${gives?.manna} Manna',
      if (gives?.generatorLevel != null)
        'a level-${gives?.generatorLevel} generator',
    ].join(' + ');
    return Card(
      key: Key('shop_product_${product.id}'),
      color: const Color(0xFF2A1F08),
      child: ListTile(
        // Always say exactly what the player gets.
        title: Text(contents, style: const TextStyle(color: _cream)),
        subtitle: Text(
          product.title,
          style: const TextStyle(color: Color(0xFFBFA77A), fontSize: 12),
        ),
        trailing: FilledButton(
          key: Key('shop_buy_${product.id}'),
          onPressed: owned || shop.busy.value
              ? null
              : () {
                  widget.onBuy?.call(product.id);
                  shop.buy(product.id);
                },
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: GamePalette.action,
            foregroundColor: GamePalette.onAction,
          ),
          // The price is the store's own, never written in the app.
          child: Text(owned ? 'Owned' : product.price),
        ),
      ),
    );
  }
}
