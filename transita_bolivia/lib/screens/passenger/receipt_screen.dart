import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/payment_receipt.dart';
import '../../widgets/amount_speaker_button.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.receipt});
  final PaymentReceipt receipt;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _imageKey = GlobalKey();
  bool _sharing = false;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.receipt.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos del comprobante copiados.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron copiar los datos. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _share(BuildContext anchorContext) async {
    if (_sharing) return;
    final origin = anchorContext.findRenderObject() as RenderBox?;
    final shareOrigin = origin == null
        ? null
        : origin.localToGlobal(Offset.zero) & origin.size;
    setState(() => _sharing = true);
    ui.Image? image;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Imagen no disponible');
      await Share.shareXFiles(
        [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png')],
        fileNameOverrides: [
          'comprobante-transita-${widget.receipt.reference}.png',
        ],
        subject: 'Comprobante Transita Bolivia',
        text: widget.receipt.text,
        sharePositionOrigin: shareOrigin,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo compartir la imagen. Puedes copiar los datos del comprobante.',
            ),
          ),
        );
      }
    } finally {
      image?.dispose();
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comprobante')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                key: _imageKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.directions_bus,
                          size: 40,
                          color: Colors.black,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'TRANSITA BOLIVIA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(widget.receipt.title, textAlign: TextAlign.center),
                        const Divider(height: 32, color: Colors.black),
                        for (final entry in widget.receipt.details.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(entry.value),
                              ],
                            ),
                          ),
                        const Divider(height: 32, color: Colors.black),
                        const Text(
                          'Consulta esta operación en el historial de tu app.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AmountSpeakerButton(
                amount: widget.receipt.transaction.puntos,
                label: 'Total del comprobante',
              ),
              const SizedBox(height: 20),
              Builder(
                builder: (anchorContext) => FilledButton.icon(
                  onPressed: _sharing ? null : () => _share(anchorContext),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(
                    _sharing ? 'Preparando imagen…' : 'Compartir comprobante',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar datos'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
