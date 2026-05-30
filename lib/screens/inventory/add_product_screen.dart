import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;
  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name, _barcode, _sku, _brand, _description;
  late TextEditingController _purchasePrice, _salePrice, _quantity, _minQty;
  late TextEditingController _size, _color;
  String? _selectedCategoryId;
  bool _isActive = true;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _purchasePrice = TextEditingController(text: p?.purchasePrice.toString() ?? '0');
    _salePrice = TextEditingController(text: p?.salePrice.toString() ?? '0');
    _quantity = TextEditingController(text: p?.quantity.toString() ?? '0');
    _minQty = TextEditingController(text: p?.minQuantity.toString() ?? '5');
    _size = TextEditingController(text: p?.size ?? '');
    _color = TextEditingController(text: p?.color ?? '');
    _selectedCategoryId = p?.categoryId;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _sku, _brand, _description, _purchasePrice, _salePrice, _quantity, _minQty, _size, _color]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل المنتج' : 'إضافة منتج'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('حفظ', style: TextStyle(color: AppColors.gold, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('المعلومات الأساسية'),
              _field('اسم المنتج *', _name, required: true),
              const SizedBox(height: 12),

              // Barcode with scanner
              Row(children: [
                Expanded(child: _field('الباركود', _barcode)),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('مسح', style: TextStyle(fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                ),
              ]),
              const SizedBox(height: 12),
              _field('SKU / رمز المنتج', _sku),
              const SizedBox(height: 12),
              _field('الماركة / الموديل', _brand),
              const SizedBox(height: 12),
              _field('الوصف', _description, maxLines: 3),
              const SizedBox(height: 20),

              _sectionTitle('التصنيف'),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                dropdownColor: AppColors.surfaceVariant,
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  labelText: 'الفئة',
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون فئة', style: TextStyle(fontFamily: 'Cairo'))),
                  ...provider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontFamily: 'Cairo')))),
                ],
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
              const SizedBox(height: 20),

              _sectionTitle('التفاصيل'),
              Row(children: [
                Expanded(child: _field('المقاس', _size)),
                const SizedBox(width: 12),
                Expanded(child: _field('اللون', _color)),
              ]),
              const SizedBox(height: 20),

              _sectionTitle('الأسعار والكميات'),
              Row(children: [
                Expanded(child: _numField('سعر الشراء *', _purchasePrice, required: true)),
                const SizedBox(width: 12),
                Expanded(child: _numField('سعر البيع *', _salePrice, required: true)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numField('الكمية *', _quantity, isInt: true, required: true)),
                const SizedBox(width: 12),
                Expanded(child: _numField('الحد الأدنى', _minQty, isInt: true)),
              ]),
              const SizedBox(height: 20),

              SwitchListTile(
                title: const Text('المنتج نشط', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppColors.gold,
                tileColor: AppColors.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.cardBorder)),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold, fontFamily: 'Cairo')),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
      validator: required ? (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, {bool required = false, bool isInt = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      textAlign: TextAlign.right,
      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
      validator: required ? (v) => v == null || v.isEmpty ? 'مطلوب' : null : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(
        height: 400,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('امسح الباركود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo', color: AppColors.textPrimary)),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (capture.barcodes.isNotEmpty) {
                  Navigator.pop(context, capture.barcodes.first.rawValue);
                }
              },
            ),
          ),
        ]),
      ),
    );
    if (result != null) {
      setState(() => _barcode.text = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ProductProvider>();

    final product = _isEditing
        ? widget.product!.copyWith(
            name: _name.text.trim(),
            barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
            sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
            brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
            salePrice: double.tryParse(_salePrice.text) ?? 0,
            quantity: int.tryParse(_quantity.text) ?? 0,
            minQuantity: int.tryParse(_minQty.text) ?? 5,
            size: _size.text.trim().isEmpty ? null : _size.text.trim(),
            color: _color.text.trim().isEmpty ? null : _color.text.trim(),
            categoryId: _selectedCategoryId,
            isActive: _isActive,
          )
        : Product.create(
            name: _name.text.trim(),
            barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
            sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
            brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
            salePrice: double.tryParse(_salePrice.text) ?? 0,
            quantity: int.tryParse(_quantity.text) ?? 0,
            minQuantity: int.tryParse(_minQty.text) ?? 5,
            size: _size.text.trim().isEmpty ? null : _size.text.trim(),
            color: _color.text.trim().isEmpty ? null : _color.text.trim(),
            categoryId: _selectedCategoryId,
          );

    if (_isEditing) {
      await provider.updateProduct(product);
    } else {
      await provider.addProduct(product);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'تم تحديث المنتج' : 'تم إضافة المنتج', style: const TextStyle(fontFamily: 'Cairo'))),
      );
      Navigator.pop(context);
    }
  }
}
