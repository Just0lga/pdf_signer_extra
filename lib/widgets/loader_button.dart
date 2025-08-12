import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/provider/pdf_provider.dart';
import '../services/local_pdf_loader.dart';
import '../services/asset_pdf_loader.dart';
import '../screens/ftp_browser_screen.dart';

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
          ),
          const SizedBox(height: 16),
          _buildButton(
            icon: Icons.folder,
            label: 'Asset\'ten PDF Yükle',
            onPressed: () =>
                notifier.loadPdf(AssetPdfLoader('assets/sample.pdf')),
          ),
          const SizedBox(height: 16),
          _buildButton(
            icon: Icons.cloud_download,
            label: 'FTP\'den PDF Yükle',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FtpBrowserScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) =>
      ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(250, 50),
        ),
      );
}
