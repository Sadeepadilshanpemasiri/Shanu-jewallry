import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';

import '../../inventory/presentation/inventory_format.dart';
import '../../shipping/domain/courier.dart';
import '../domain/shop_order.dart';

Future<Uint8List> orderPdf(ShopOrder order, {required bool label}) async {
  final document = pdf.Document(
    title: label ? 'Courier label ${order.number}' : 'Invoice ${order.number}',
  );
  final regular = await PdfGoogleFonts.notoSansRegular();
  final sinhala = await PdfGoogleFonts.notoSansSinhalaRegular();
  final theme = pdf.ThemeData.withFont(base: regular, fontFallback: [sinhala]);
  document.addPage(
    pdf.MultiPage(
      theme: theme,
      pageFormat: label ? PdfPageFormat.a6 : PdfPageFormat.a4,
      margin: const pdf.EdgeInsets.all(24),
      build: (_) => [
        pdf.Text(
          label ? 'Courier label' : 'Jewellery Business Manager',
          style: const pdf.TextStyle(fontSize: 18),
        ),
        pdf.Text(order.number),
        pdf.SizedBox(height: 14),
        pdf.Text(order.customer.name),
        pdf.Text(order.customer.phone),
        pdf.Text('${order.customer.address}, ${order.customer.city}'),
        if (label) ...[
          pdf.SizedBox(height: 12),
          pdf.Center(
            child: pdf.BarcodeWidget(
              barcode: pdf.Barcode.qrCode(),
              data: parcelLabelCode(order.id),
              width: 92,
              height: 92,
              drawText: false,
            ),
          ),
          pdf.SizedBox(height: 8),
          if (order.courier.isNotEmpty)
            pdf.Text('${order.courier} | ${order.tracking}'),
          if (order.payment == OrderPayment.cod)
            pdf.Text('COD due ${lkr(order.remaining)}'),
        ] else ...[
          pdf.SizedBox(height: 14),
          pdf.TableHelper.fromTextArray(
            headers: ['Item', 'Qty', 'Unit price', 'Amount'],
            data: [
              for (final item in order.lines)
                [
                  item.name,
                  item.quantity.toString(),
                  lkr(item.price),
                  lkr(item.price * item.quantity),
                ],
            ],
          ),
          pdf.SizedBox(height: 12),
          pdf.Text('Subtotal: ${lkr(order.totals.subtotal)}'),
          pdf.Text('Delivery: ${lkr(order.totals.delivery)}'),
          pdf.Text('Discount: ${lkr(order.totals.discount)}'),
          pdf.Text('Total: ${lkr(order.totals.total)}'),
          pdf.Text('Payment: ${order.payment.label}'),
          pdf.Text('Outstanding: ${lkr(order.remaining)}'),
        ],
      ],
    ),
  );
  return document.save();
}
