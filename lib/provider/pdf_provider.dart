import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/pdf_state.dart';
import '../services/pdf_loader_service.dart';

final pdfProvider = StateNotifierProvider<PdfNotifier, PdfState>(
  (ref) => PdfNotifier(),
);

class PdfNotifier extends StateNotifier<PdfState> {
  PdfNotifier() : super(const PdfState());

  Future<void> loadPdf(PdfLoaderService loader) async {
    state = state.copyWith(isLoading: true);

    try {
      final bytes = await loader.loadPdf();
      if (bytes == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final document = sf.PdfDocument(inputBytes: bytes);
      final totalPages = document.pages.count;
      final pageSizes = <int, Size>{};

      for (int i = 0; i < totalPages; i++) {
        final pageSize = document.pages[i].getClientSize();
        pageSizes[i] = Size(pageSize.width, pageSize.height);
      }

      state = PdfState(
        pdfBytes: bytes,
        document: document,
        totalPages: totalPages,
        pageSizes: pageSizes,
        signatures: {},
        renderedImages: {},
      );
    } catch (e) {
      print('PDF yükleme hatası: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<Uint8List?> renderPage(int pageIndex) async {
    if (state.pdfBytes == null) return null;

    if (state.renderedImages.containsKey(pageIndex)) {
      return state.renderedImages[pageIndex];
    }

    try {
      await for (final page in Printing.raster(
        state.pdfBytes!,
        pages: [pageIndex],
        dpi: 150,
      )) {
        final image = await page.toPng();

        Future.delayed(Duration.zero, () {
          state = state.copyWith(
            renderedImages: {...state.renderedImages, pageIndex: image},
          );
        });

        return image;
      }
    } catch (e) {
      print('Render hatası sayfa $pageIndex: $e');
    }

    return null;
  }

  void updateSignature(String key, Uint8List? signature) {
    state = state.copyWith(
      signatures: {...state.signatures, key: signature},
    );
  }

  void clearSignature(String key) {
    final signatures = Map<String, Uint8List?>.from(state.signatures);
    signatures.remove(key);
    state = state.copyWith(signatures: signatures);
  }

  void reset() {
    state.document?.dispose();
    state = const PdfState();
  }

  Future<Uint8List> createSignedPDF() async {
    if (state.pdfBytes == null || state.document == null) {
      throw Exception('PDF yüklenmemiş');
    }

    final document = sf.PdfDocument(inputBytes: state.pdfBytes!);

    try {
      for (int pageIndex = 0; pageIndex < state.totalPages; pageIndex++) {
        final page = document.pages[pageIndex];
        final graphics = page.graphics;
        final pageSize = page.getClientSize();

        const signatureWidth = 120.0;
        const signatureHeight = 60.0;
        const bottomMargin = 20.0;
        final spacing = (pageSize.width - signatureWidth * 4) / 5;

        for (int signatureIndex = 0; signatureIndex < 4; signatureIndex++) {
          final key = '${pageIndex}_$signatureIndex';
          final xPosition =
              spacing + (signatureIndex * (signatureWidth + spacing));
          final yPosition = pageSize.height - signatureHeight - bottomMargin;

          if (state.signatures.containsKey(key) &&
              state.signatures[key] != null) {
            try {
              final signatureImage = sf.PdfBitmap(state.signatures[key]!);
              graphics.drawImage(
                signatureImage,
                Rect.fromLTWH(
                    xPosition, yPosition, signatureWidth, signatureHeight),
              );
            } catch (e) {
              _drawEmptyBox(graphics, xPosition, yPosition, signatureWidth,
                  signatureHeight, signatureIndex);
            }
          }
        }
      }

      final bytes = await document.save();
      return Uint8List.fromList(bytes);
    } finally {
      document.dispose();
    }
  }

  void _drawEmptyBox(sf.PdfGraphics graphics, double x, double y, double width,
      double height, int index) {
    graphics.drawRectangle(
      pen: sf.PdfPen(sf.PdfColor(255, 0, 0), width: 2),
      bounds: Rect.fromLTWH(x, y, width, height),
    );

    graphics.drawString(
      'İmza ${index + 1}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10),
      bounds: Rect.fromLTWH(x + 5, y + height / 2 - 5, width - 10, 20),
      brush: sf.PdfSolidBrush(sf.PdfColor(255, 0, 0)),
    );
  }
}
