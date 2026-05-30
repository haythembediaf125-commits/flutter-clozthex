import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/pdf_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  List<Product> _searchResults = [];
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<SaleProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          if (cart.cartCount > 0) ...[
            TextButton(
              onPressed: () => _showClearConfirm(context, cart),
              child: const Text('مسح السلة', style: TextStyle(color: AppColors.error, fontFamily: 'Cairo', fontSize: 12)),
            ),
          ],
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: cart.cartCount > 0 ? () => _openCart(context, currency) : null,
              ),
              if (cart.cartCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${cart.cartCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search bar ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            color: AppColors.background,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المنتج أو الباركود...',
                    hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: _showSearch
                        ? IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() { _showSearch = false; _searchResults = []; });
                            },
                          )
                        : const Icon(Icons.search, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.black, size: 22),
                  onPressed: _scanBarcode,
                  tooltip: 'مسح باركود',
                ),
              ),
            ]),
          ),

          // ─── Product area ─────────────────────────────────────────────────
          Expanded(
            child: _showSearch
                ? _buildSearchResults(context, currency)
                : _buildProductGrid(context, currency),
          ),
        ],
      ),

      // ─── Bottom Cart Bar ──────────────────────────────────────────────────
      bottomNavigationBar: cart.cartCount > 0
          ? _CartSummaryBar(
              currency: currency,
              itemCount: cart.cartCount,
              total: cart.total,
              onTap: () => _openCart(context, currency),
            )
          : null,
    );
  }

  // ─── Product Grid ─────────────────────────────────────────────────────────

  Widget _buildProductGrid(BuildContext context, String currency) {
    final products = context.watch<ProductProvider>().products;
    if (products.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('لا توجد منتجات', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 15)),
        ]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => _ProductCard(
        product: products[i],
        currency: currency,
        onTap: () {
          if (!products[i].isOutOfStock) {
            context.read<SaleProvider>().addToCart(products[i]);
            _showAddedSnack(products[i].name);
          }
        },
      ),
    );
  }

  // ─── Search Results ───────────────────────────────────────────────────────

  Widget _buildSearchResults(BuildContext context, String currency) {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text('لا توجد نتائج', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _searchResults[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: p.isOutOfStock ? AppColors.surfaceVariant : AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.checkroom, color: p.isOutOfStock ? AppColors.textMuted : AppColors.gold, size: 20),
            ),
            title: Text(p.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.salePrice.toStringAsFixed(2)} $currency',
                style: const TextStyle(fontFamily: 'Cairo', color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
              if (p.barcode != null)
                Text(p.barcode!, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
            ]),
            trailing: p.isOutOfStock
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Text('نفذ', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                  )
                : ElevatedButton(
                    onPressed: () {
                      context.read<SaleProvider>().addToCart(p);
                      _searchCtrl.clear();
                      setState(() { _showSearch = false; _searchResults = []; });
                      _showAddedSnack(p.name);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(60, 36),
                    ),
                    child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  ),
          ),
        );
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _onSearch(String q) async {
    if (q.isEmpty) {
      setState(() { _showSearch = false; _searchResults = []; });
      return;
    }
    final all = context.read<ProductProvider>().allProducts;
    final lq = q.toLowerCase();
    final results = all.where((p) =>
      p.name.toLowerCase().contains(lq) ||
      (p.barcode?.contains(q) ?? false) ||
      (p.brand?.toLowerCase().contains(lq) ?? false)
    ).take(15).toList();
    // Try exact barcode match first
    final exact = await context.read<ProductProvider>().getByBarcode(q);
    if (exact != null && !results.any((p) => p.id == exact.id)) results.insert(0, exact);
    setState(() { _showSearch = true; _searchResults = results; });
  }

  Future<void> _scanBarcode() async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BarcodeScanSheet(),
    );
    if (barcode != null && mounted) {
      final product = await context.read<ProductProvider>().getByBarcode(barcode);
      if (product != null && mounted) {
        context.read<SaleProvider>().addToCart(product);
        _showAddedSnack(product.name);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على المنتج بهذا الباركود', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  void _openCart(BuildContext context, String currency) {
    // Capture PosScreen context before entering modal (remains valid after pop)
    final posCtx = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => _CartSheet(
          currency: currency,
          scrollController: scrollCtrl,
          onSaleCompleted: (sale) {
            // Called from CartSheet AFTER Navigator.pop — posCtx is still valid
            if (posCtx.mounted) {
              posCtx.read<ProductProvider>().loadAll();
              _showSuccessDialog(sale, posCtx);
            }
          },
        ),
      ),
    );
  }

  void _showSuccessDialog(Sale sale, BuildContext ctx) {
    final settings = ctx.read<SettingsProvider>();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 26),
          SizedBox(width: 8),
          Text('تمت عملية البيع!',
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontSize: 17)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('رقم الفاتورة: ${sale.invoiceNumber}',
            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Text('${sale.total.toStringAsFixed(2)} ${settings.currency}',
            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.gold,
              fontWeight: FontWeight.w800, fontSize: 22)),
          if (sale.changeAmount > 0) ...[
            const SizedBox(height: 4),
            Text('الباقي للعميل: ${sale.changeAmount.toStringAsFixed(2)} ${settings.currency}',
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.success, fontWeight: FontWeight.w600)),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await PdfService.printInvoice(sale,
                storeName: settings.storeName,
                storePhone: settings.storePhone,
                currency: settings.currency);
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('طباعة فاتورة', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _showAddedSnack(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('تمت إضافة $name', style: const TextStyle(fontFamily: 'Cairo'))),
      ]),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
    ));
  }

  void _showClearConfirm(BuildContext context, SaleProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('مسح السلة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
        content: const Text('هل تريد مسح جميع المنتجات من السلة؟', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () { cart.clearCart(); Navigator.pop(context); },
            child: const Text('مسح', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

// ─── Product Card Widget ──────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final String currency;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOut = product.isOutOfStock;
    return GestureDetector(
      onTap: isOut ? null : onTap,
      child: Opacity(
        opacity: isOut ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon area
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: isOut ? AppColors.surfaceVariant : AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.checkroom, size: 18, color: isOut ? AppColors.textMuted : AppColors.gold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(product.name,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 4),
              Text('${product.salePrice.toStringAsFixed(2)} $currency',
                style: const TextStyle(fontFamily: 'Cairo', color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 14)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isOut ? 'نفذ' : 'الكمية: ${product.quantity}',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: isOut ? AppColors.error : AppColors.textMuted)),
                if (!isOut)
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.add, size: 14, color: Colors.black),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cart Summary Bottom Bar ──────────────────────────────────────────────────

class _CartSummaryBar extends StatelessWidget {
  final String currency;
  final int itemCount;
  final double total;
  final VoidCallback onTap;
  const _CartSummaryBar({required this.currency, required this.itemCount, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.gold,
          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
            child: Text('$itemCount منتج', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_cart, color: Colors.black, size: 18),
              SizedBox(width: 6),
              Text('عرض السلة', style: TextStyle(fontFamily: 'Cairo', color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
          Text('${total.toStringAsFixed(2)} $currency',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.black, size: 20),
        ]),
      ),
    );
  }
}

// ─── Barcode Scanner Sheet ────────────────────────────────────────────────────

class _BarcodeScanSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
        ),
        const Text('امسح الباركود', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: MobileScanner(
              onDetect: (c) {
                if (c.barcodes.isNotEmpty) Navigator.pop(context, c.barcodes.first.rawValue);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Full Cart Sheet ──────────────────────────────────────────────────────────

class _CartSheet extends StatefulWidget {
  final String currency;
  final ScrollController scrollController;
  final void Function(Sale sale) onSaleCompleted;
  const _CartSheet({
    required this.currency,
    required this.scrollController,
    required this.onSaleCompleted,
  });

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _paidCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DiscountType _discountType = DiscountType.fixed;
  bool _processing = false;

  @override
  void dispose() {
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<SaleProvider>();
    final currency = widget.currency;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle + header
        _buildSheetHeader(context, cart),

        // Cart items
        if (cart.cart.isEmpty)
          const Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shopping_cart_outlined, size: 56, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text('السلة فارغة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 15)),
              ]),
            ),
          )
        else ...[
          Expanded(
            child: ListView.separated(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: cart.cart.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildCartItem(context, cart, cart.cart[i], currency),
            ),
          ),
          _buildCheckoutPanel(context, cart, currency),
        ],
      ]),
    );
  }

  Widget _buildSheetHeader(BuildContext context, SaleProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
        ),
        Row(children: [
          const Icon(Icons.shopping_cart, color: AppColors.gold, size: 22),
          const SizedBox(width: 8),
          const Text('السلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text('${cart.cartCount} منتج', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildCartItem(BuildContext context, SaleProvider cart, dynamic item, String currency) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        // Product icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.checkroom, color: AppColors.gold, size: 20),
        ),
        const SizedBox(width: 10),
        // Name + price
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.productName,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${item.unitPrice.toStringAsFixed(2)} $currency',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
          ]),
        ),
        // Qty controls
        Container(
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _qtyBtn(Icons.remove, () => cart.updateCartItemQuantity(item.productId, item.quantity - 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.quantity}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14)),
            ),
            _qtyBtn(Icons.add, () => cart.updateCartItemQuantity(item.productId, item.quantity + 1)),
          ]),
        ),
        const SizedBox(width: 10),
        // Total + delete
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${item.total.toStringAsFixed(2)} $currency',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: AppColors.gold, fontSize: 13)),
          GestureDetector(
            onTap: () => cart.removeFromCart(item.productId),
            child: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
          ),
        ]),
      ]),
    );
  }

  Widget _buildCheckoutPanel(BuildContext context, SaleProvider cart, String currency) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(children: [
        // Discount row
        Row(children: [
          Expanded(
            child: TextField(
              controller: _discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontSize: 14),
              onChanged: (v) => cart.setDiscount(double.tryParse(v) ?? 0, _discountType),
              decoration: InputDecoration(
                labelText: 'الخصم',
                labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ToggleButtons(
            isSelected: [_discountType == DiscountType.fixed, _discountType == DiscountType.percentage],
            onPressed: (i) {
              setState(() => _discountType = i == 0 ? DiscountType.fixed : DiscountType.percentage);
              cart.setDiscount(double.tryParse(_discountCtrl.text) ?? 0, _discountType);
            },
            borderColor: AppColors.inputBorder,
            selectedBorderColor: AppColors.gold,
            selectedColor: AppColors.gold,
            fillColor: AppColors.gold.withOpacity(0.15),
            color: AppColors.textMuted,
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 42),
            children: const [
              Text('دج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
              Text('%', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
            ],
          ),
        ]),
        const SizedBox(height: 10),

        // Payment method
        Row(children: [
          const Text('طريقة الدفع: ', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          ...PaymentMethod.values.map((m) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text(_methodLabel(m), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              selected: _paymentMethod == m,
              onSelected: (_) { setState(() => _paymentMethod = m); cart.setPaymentMethod(m); },
              selectedColor: AppColors.gold.withOpacity(0.2),
              labelStyle: TextStyle(color: _paymentMethod == m ? AppColors.gold : AppColors.textSecondary),
              side: BorderSide(color: _paymentMethod == m ? AppColors.gold : AppColors.cardBorder),
              backgroundColor: AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
            ),
          )),
        ]),
        const SizedBox(height: 10),

        // Totals
        _summaryRow('المجموع الفرعي', '${cart.subtotal.toStringAsFixed(2)} $currency'),
        if (cart.discountAmount > 0)
          _summaryRow('الخصم', '−${cart.discountAmount.toStringAsFixed(2)} $currency', color: AppColors.error),
        if (cart.taxAmount > 0)
          _summaryRow('الضريبة', '${cart.taxAmount.toStringAsFixed(2)} $currency'),
        const Divider(color: AppColors.divider, height: 14),
        _summaryRow('الإجمالي', '${cart.total.toStringAsFixed(2)} $currency', bold: true, color: AppColors.gold, large: true),
        const SizedBox(height: 10),

        // Paid amount (cash only)
        if (_paymentMethod == PaymentMethod.cash) ...[
          TextField(
            controller: _paidCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            onChanged: (v) => cart.setPaid(double.tryParse(v) ?? 0),
            decoration: InputDecoration(
              labelText: 'المبلغ المدفوع',
              hintText: cart.total.toStringAsFixed(2),
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.textMuted),
            ),
          ),
          if (cart.change > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: _summaryRow('الباقي للعميل', '${cart.change.toStringAsFixed(2)} $currency', color: AppColors.success, bold: true),
            ),
          ],
          const SizedBox(height: 10),
        ],

        // Complete button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: cart.cart.isEmpty || _processing ? null : _completeSale,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _processing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.check_circle_outline, size: 22),
            label: Text(
              'إتمام البيع${cart.cart.isNotEmpty ? '  •  ${cart.cartCount} منتج' : ''}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color, bool large = false}) {
    final size = large ? 15.0 : 13.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: size, color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: size, color: color ?? AppColors.textPrimary, fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
      ]),
    );
  }

  String _methodLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash: return 'نقدي';
      case PaymentMethod.card: return 'بطاقة';
      case PaymentMethod.transfer: return 'تحويل';
    }
  }

  Future<void> _completeSale() async {
    final cart = context.read<SaleProvider>();
    if (cart.cart.isEmpty) return;

    // Set paid amount based on payment method
    if (_paymentMethod == PaymentMethod.cash) {
      final paidAmount = double.tryParse(_paidCtrl.text) ?? cart.total;
      cart.setPaid(paidAmount);
    } else {
      cart.setPaid(cart.total);
    }

    setState(() => _processing = true);
    try {
      final sale = await cart.completeSale();
      if (mounted) {
        _paidCtrl.clear();
        _discountCtrl.text = '0';
        Navigator.pop(context);
        widget.onSaleCompleted(sale);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'فشل إتمام البيع';
        if (e.toString().contains('السلة فارغة')) {
          errorMsg = 'السلة فارغة - لا يمكن إتمام البيع';
        } else if (e.toString().contains('المبلغ المدفوع')) {
          errorMsg = 'المبلغ المدفوع أقل من إجمالي الفاتورة';
        } else {
          errorMsg = 'حدث خطأ: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
