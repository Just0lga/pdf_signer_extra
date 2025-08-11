// services/pdf_loader_service.dart

import 'dart:typed_data';

abstract class PdfLoaderService {
  Future<Uint8List?> loadPdf();
}
