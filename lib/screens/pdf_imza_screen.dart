import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/models/pdf_state.dart';
import 'package:pdf_signer_extra/provider/pdf_provider.dart';
import 'package:pdf_signer_extra/widgets/loader_button.dart';
import 'package:printing/printing.dart';
import '../services/ftp_pdf_loader.dart';
import '../widgets/pdf_page_widget.dart';
import '../widgets/signature_dialog.dart';

class PdfImzaScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfState = ref.watch(pdfProvider);
    final pdfNotifier = ref.read(pdfProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('PDF İmzala',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Color(0xFF5fd8e7),
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: _buildActions(context, pdfState, pdfNotifier),
        leading: _buildLeading(context, pdfState, pdfNotifier),
      ),
      body: _buildBody(context, ref, pdfState, pdfNotifier),
    );
  }

  List<Widget>? _buildActions(
      BuildContext context, PdfState state, PdfNotifier notifier) {
    if (state.document == null || state.isLoading) {
      return state.isLoading ? [_buildLoadingIndicator()] : null;
    }

    return [
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _sharePDF(context, notifier),
        tooltip: 'Paylaş',
      ),
      IconButton(
        icon: const Icon(Icons.save),
        onPressed: () => _savePDF(context, notifier),
        tooltip: 'Kaydet',
      ),
    ];
  }

  Widget? _buildLeading(
      BuildContext context, PdfState state, PdfNotifier notifier) {
    if (state.pdfBytes == null) return null;

    return IconButton(
      onPressed: state.isLoading
          ? null
          : () {
              if (state.pdfBytes != null) {
                notifier.reset();
              } else {
                Navigator.pop(context);
              }
            },
      icon: const Icon(Icons.arrow_back),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, PdfState state,
      PdfNotifier notifier) {
    if (state.isLoading) return _buildLoadingScreen();
    if (state.pdfBytes == null) return LoaderButtons();

    return ListView.builder(
      itemCount: state.totalPages,
      shrinkWrap: false,
      cacheExtent: 1000,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemBuilder: (context, pageIndex) => PdfPageWidget(
        key: ValueKey('pdf_page_$pageIndex'),
        pageIndex: pageIndex,
        onSignatureTap: (signatureIndex) => _showSignatureDialog(
          context,
          ref,
          pageIndex,
          signatureIndex,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5fd8e7)),
            ),
          ),
        ),
      );

  Widget _buildLoadingScreen() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF5fd8e7)),
            SizedBox(height: 16),
            Text('İşlem yapılıyor...'),
          ],
        ),
      );

  void _showSignatureDialog(
      BuildContext context, WidgetRef ref, int pageIndex, int signatureIndex) {
    showDialog(
      context: context,
      builder: (context) => SignatureDialog(
        pageIndex: pageIndex,
        signatureIndex: signatureIndex,
      ),
    );
  }

  Future<void> _savePDF(BuildContext context, PdfNotifier notifier) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF5fd8e7)),
            SizedBox(width: 16),
            Text('PDF kaydediliyor...'),
          ],
        ),
      ),
    );

    try {
      final result = await notifier.createSignedPDF();
      final Uint8List signedPdfBytes = result['bytes'];
      final String fileName = '${result['fileName']}.pdf';

      // Dosya var mı kontrol et
      final existingFiles = await FtpPdfLoader.listPdfFiles(
        host: '192.168.137.253',
        username: 'tolga',
        password: '1234',
      );

      final fileExists = existingFiles.any((file) => file.name == fileName);
      bool shouldOverwrite = true;

      // Loading'i kapat
      if (context.mounted) Navigator.pop(context);

      // Eğer dosya varsa kullanıcıya sor
      if (fileExists && context.mounted) {
        shouldOverwrite = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Dosya Mevcut'),
                content: Text(
                    '$fileName zaten mevcut. Üstüne yazmak istiyor musunuz?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Üstüne Yaz'),
                  ),
                ],
              ),
            ) ??
            false;
      }

      if (!shouldOverwrite) return;

      // Upload loading göster
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF5fd8e7)),
                SizedBox(width: 16),
                Text('FTP\'ye yükleniyor...'),
              ],
            ),
          ),
        );
      }

      // FTP'ye yükle
      final success = await FtpPdfLoader.uploadPdfToFtp(
        host: '192.168.137.253',
        username: 'tolga',
        password: '1234',
        pdfBytes: signedPdfBytes,
        fileName: fileName,
        overwrite: shouldOverwrite,
      );

      // Loading'i kapat
      if (context.mounted) Navigator.pop(context);

      // Sonuç göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'PDF kaydedildi: $fileName'
                : 'PDF kaydetme başarısız!'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      // Loading'i kapat
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF(BuildContext context, PdfNotifier notifier) async {
    try {
      // Map döndüren createSignedPDF'yi çağır
      final Map<String, dynamic> result = await notifier.createSignedPDF();

      // Map'ten bytes ve fileName'i çıkar
      final Uint8List signedPdfBytes = result['bytes'];
      final String fileName = result['fileName'];

      await Printing.sharePdf(
        bytes: signedPdfBytes, // Artık doğru tip: Uint8List
        filename: '$fileName.pdf', // Dinamik dosya adı
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF paylaşma hatası: $e')),
        );
      }
    }
  }
}
