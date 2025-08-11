// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/models/pdf_state.dart';
import 'package:pdf_signer_extra/provider/pdf_notifier.dart';
import 'package:pdf_signer_extra/widgets/loader_button.dart';
import 'package:pdf_signer_extra/widgets/pdf_page_widget.dart';
import 'package:pdf_signer_extra/widgets/signature_dialog.dart';
import 'package:printing/printing.dart';

// screens/pdf_imza_screen.dart

class PdfImzaScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfState = ref.watch(pdfProvider);
    final pdfNotifier = ref.read(pdfProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF İmzala'),
        centerTitle: true,
        backgroundColor: Colors.black,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
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
      icon: const Icon(Icons.arrow_back_ios_new),
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );

  Widget _buildLoadingScreen() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
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
    try {
      final signedPdfBytes = await notifier.createSignedPDF();
      await Printing.layoutPdf(
        onLayout: (_) async => signedPdfBytes,
        name: 'signed_document.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF başarıyla kaydedildi')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF kaydetme hatası: $e')),
        );
      }
    }
  }

  Future<void> _sharePDF(BuildContext context, PdfNotifier notifier) async {
    try {
      final signedPdfBytes = await notifier.createSignedPDF();
      await Printing.sharePdf(
        bytes: signedPdfBytes,
        filename: 'signed_document.pdf',
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
