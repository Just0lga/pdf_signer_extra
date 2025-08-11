// widgets/loader_buttons.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/provider/pdf_notifier.dart';
import 'package:pdf_signer_extra/services/asset_pdf_loader.dart';
import 'package:pdf_signer_extra/services/ftp_pdf_loader.dart';
import 'package:pdf_signer_extra/services/local_pdf_loader.dart';

class LoaderButtons extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pdfProvider.notifier);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildButton(
              icon: Icons.upload_file,
              label: 'Lokalden PDF Yükle',
              onPressed: () => notifier.loadPdf(LocalPdfLoader()),
              color: const Color.fromARGB(255, 11, 117, 14)),
          const SizedBox(height: 16),
          _buildButton(
              icon: Icons.folder,
              label: 'Asset\'ten PDF Yükle',
              onPressed: () =>
                  notifier.loadPdf(AssetPdfLoader('assets/sample.pdf')),
              color: Colors.blue),
          const SizedBox(height: 16),
          _buildButton(
              icon: Icons.cloud_download,
              label: 'FTP\'den PDF Yükle',
              onPressed: () => notifier.loadPdf(FtpPdfLoader(
                    host: 'ftp.example.com',
                    username: 'user',
                    password: 'pass',
                    filePath: '/path/to/file.pdf',
                  )),
              color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) =>
      GestureDetector(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
}
