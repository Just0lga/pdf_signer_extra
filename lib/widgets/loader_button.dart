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
          /*
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
          ),*/
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
      GestureDetector(
          onTap: onPressed,
          child: Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.white),
                ),
                SizedBox(
                  width: 16,
                ),
                Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                )
              ],
            ),
          ));
}
