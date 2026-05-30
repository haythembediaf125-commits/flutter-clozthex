import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/product.dart';

class PdfService {
  static final _goldColor = PdfColor.fromHex('D4A017');
  static final _darkColor = PdfColor.fromHex('1A1A1A');
  static final _lightGray = PdfColor.fromHex('F5F5F5');

  // ─── Invoice PDF ──────────────────────────────────────────────────────────

  static Future<void> printInvoice(Sale sale, {String storeName = 'ClowtheX', String storePhone = '', String currency = 'دج'}) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      textDirection: pw.TextDirection.rtl,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(color: _goldColor),
              child: pw.Column(
                children: [
                  pw.Text(storeName,
                    style: pw.TextStyle(font: arabicFontBold, fontSize: 22, color: PdfColors.black)),
                  pw.SizedBox(height: 4),
                  if (storePhone.isNotEmpty)
                    pw.Text(storePhone,
                      style: pw.TextStyle(font: arabicFont, fontSize: 12, color: PdfColors.black)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Invoice Info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _infoRow(arabicFont, 'رقم الفاتورة', sale.invoiceNumber),
                    _infoRow(arabicFont, 'التاريخ',
                      DateFormat('yyyy/MM/dd HH:mm').format(sale.createdAt)),
                    _infoRow(arabicFont, 'طريقة الدفع', sale.paymentMethodAr),
                  ]),
                  if (sale.customerName != null)
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      _infoRow(arabicFont, 'العميل', sale.customerName!),
                    ]),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _darkColor),
                  children: [
                    _tableHeader(arabicFontBold, 'المنتج'),
                    _tableHeader(arabicFontBold, 'الكمية'),
                    _tableHeader(arabicFontBold, 'السعر'),
                    _tableHeader(arabicFontBold, 'الإجمالي'),
                  ],
                ),
                ...sale.items.map((item) => pw.TableRow(
                  children: [
                    _tableCell(arabicFont, item.productName),
                    _tableCell(arabicFont, item.quantity.toString()),
                    _tableCell(arabicFont, '${item.unitPrice.toStringAsFixed(2)} $currency'),
                    _tableCell(arabicFont, '${item.total.toStringAsFixed(2)} $currency'),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 12),

            // Totals
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                width: 200,
                child: pw.Column(children: [
                  _totalRow(arabicFont, 'المجموع الفرعي', sale.subtotal, currency),
                  if (sale.discount > 0)
                    _totalRow(arabicFont, 'الخصم', -sale.discountAmount, currency, isDiscount: true),
                  if (sale.tax > 0)
                    _totalRow(arabicFont, 'الضريبة', sale.tax, currency),
                  pw.Divider(),
                  _totalRow(arabicFontBold, 'الإجمالي', sale.total, currency, isBold: true),
                  _totalRow(arabicFont, 'المدفوع', sale.paid, currency),
                  if (sale.changeAmount > 0)
                    _totalRow(arabicFont, 'الباقي', sale.changeAmount, currency),
                ]),
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text('شكراً لتعاملكم معنا!',
                style: pw.TextStyle(font: arabicFontBold, fontSize: 14, color: _goldColor)),
            ),
          ],
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ─── Inventory Report PDF ─────────────────────────────────────────────────

  static Future<void> printInventoryReport(List<Product> products, {String currency = 'دج'}) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      textDirection: pw.TextDirection.rtl,
      build: (context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Text('تقرير المخزون - ClowtheX',
              style: pw.TextStyle(font: arabicFontBold, fontSize: 20, color: _goldColor)),
          ),
          pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
            style: pw.TextStyle(font: arabicFont, fontSize: 12)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _darkColor),
                children: ['المنتج', 'الفئة', 'سعر الشراء', 'سعر البيع', 'الكمية', 'قيمة المخزون', 'الحالة']
                  .map((h) => _tableHeader(arabicFontBold, h)).toList(),
              ),
              ...products.map((p) => pw.TableRow(
                decoration: p.isOutOfStock
                    ? pw.BoxDecoration(color: PdfColor.fromHex('FEE2E2'))
                    : p.isLowStock
                        ? pw.BoxDecoration(color: PdfColor.fromHex('FEF9C3'))
                        : null,
                children: [
                  _tableCell(arabicFont, p.name),
                  _tableCell(arabicFont, p.categoryName ?? '-'),
                  _tableCell(arabicFont, '${p.purchasePrice.toStringAsFixed(2)} $currency'),
                  _tableCell(arabicFont, '${p.salePrice.toStringAsFixed(2)} $currency'),
                  _tableCell(arabicFont, p.quantity.toString()),
                  _tableCell(arabicFont, '${(p.quantity * p.purchasePrice).toStringAsFixed(2)} $currency'),
                  _tableCell(arabicFont, p.isOutOfStock ? 'نفذ' : p.isLowStock ? 'منخفض' : 'متوفر'),
                ],
              )),
            ],
          ),
        ];
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ─── Sales Report PDF ─────────────────────────────────────────────────────

  static Future<void> printSalesReport(
    List<Sale> sales,
    Map<String, dynamic> stats, {
    String currency = 'دج',
    String period = '',
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      build: (context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Text('تقرير المبيعات${period.isNotEmpty ? ' - $period' : ''}',
              style: pw.TextStyle(font: arabicFontBold, fontSize: 20, color: _goldColor)),
          ),
          pw.SizedBox(height: 8),
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: _lightGray, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _statWidget(arabicFontBold, arabicFont, 'إجمالي الفواتير', sales.length.toString()),
                _statWidget(arabicFontBold, arabicFont, 'إجمالي الإيرادات',
                  '${sales.fold<double>(0, (s, e) => s + e.total).toStringAsFixed(2)} $currency'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _darkColor),
                children: ['الفاتورة', 'التاريخ', 'العميل', 'الإجمالي', 'الدفع', 'الحالة']
                  .map((h) => _tableHeader(arabicFontBold, h)).toList(),
              ),
              ...sales.map((s) => pw.TableRow(children: [
                _tableCell(arabicFont, s.invoiceNumber),
                _tableCell(arabicFont, DateFormat('yyyy/MM/dd').format(s.createdAt)),
                _tableCell(arabicFont, s.customerName ?? 'عميل عام'),
                _tableCell(arabicFont, '${s.total.toStringAsFixed(2)} $currency'),
                _tableCell(arabicFont, s.paymentMethodAr),
                _tableCell(arabicFont, s.statusAr),
              ])),
            ],
          ),
        ];
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static pw.Widget _infoRow(pw.Font font, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label: ', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
        pw.TextSpan(text: value, style: pw.TextStyle(font: font, fontSize: 10)),
      ])),
    );
  }

  static pw.Widget _tableHeader(pw.Font font, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 11)),
    );
  }

  static pw.Widget _tableCell(pw.Font font, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10)),
    );
  }

  static pw.Widget _totalRow(pw.Font font, String label, double amount, String currency, {bool isBold = false, bool isDiscount = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
        pw.Text('${amount.toStringAsFixed(2)} $currency',
          style: pw.TextStyle(font: font, fontSize: 11,
            color: isDiscount ? PdfColors.red : null)),
      ]),
    );
  }

  static pw.Widget _statWidget(pw.Font boldFont, pw.Font font, String label, String value) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 16)),
      pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
    ]);
  }
}
