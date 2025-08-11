// services/local_pdf_loader.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_signer_extra/services/pdf_loader_service.dart';

class LocalPdfLoader implements PdfLoaderService {
  @override
  Future<Uint8List?> loadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return null;

    return kIsWeb
        ? result.files.single.bytes
        : File(result.files.single.path!).readAsBytesSync();
  }
}
