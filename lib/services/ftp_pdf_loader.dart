// services/ftp_pdf_loader.dart

import 'dart:typed_data';

import 'package:pdf_signer_extra/services/pdf_loader_service.dart';

class FtpPdfLoader implements PdfLoaderService {
  final String host;
  final String username;
  final String password;
  final String filePath;

  FtpPdfLoader({
    required this.host,
    required this.username,
    required this.password,
    required this.filePath,
  });

  @override
  Future<Uint8List?> loadPdf() async {
    // Mock implementation - add ftpconnect package for real implementation
    return null;
  }
}
