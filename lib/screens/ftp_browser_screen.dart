import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/provider/ftp_provider.dart';
import 'package:pdf_signer_extra/provider/pdf_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'dart:typed_data';
import '../models/ftp_file.dart';
import '../services/ftp_pdf_loader.dart';

class FtpBrowserScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<FtpBrowserScreen> createState() => _FtpBrowserScreenState();
}

class _FtpBrowserScreenState extends ConsumerState<FtpBrowserScreen> {
  final String _host = '10.0.2.2';
  final String _username = 'tolga';
  final String _password = '1234';
  final int _port = 21;
  final String _directory = '/';

  bool _isLoading = false;
  bool _showAllFiles = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectAndList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP PDF Listesi'),
        actions: [
          IconButton(
            icon: Icon(_showAllFiles ? Icons.picture_as_pdf : Icons.folder),
            onPressed: () {
              setState(() {
                _showAllFiles = !_showAllFiles;
              });
              _connectAndList();
            },
            tooltip: _showAllFiles ? 'Sadece PDF' : 'Tüm Dosyalar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _connectAndList,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sunucu: $_host',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Kullanıcı: $_username',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _showAllFiles
                      ? 'Tüm Dosyalar Gösteriliyor'
                      : 'Sadece PDF Dosyaları',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return FutureBuilder<List<FtpFile>>(
      future: _showAllFiles
          ? FtpPdfLoader.listAllFiles(
              host: _host,
              username: _username,
              password: _password,
              directory: _directory,
              port: _port,
            )
          : FtpPdfLoader.listPdfFiles(
              host: _host,
              username: _username,
              password: _password,
              directory: _directory,
              port: _port,
            ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Hata: ${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _connectAndList,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          );
        }

        final files = snapshot.data ?? [];

        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_showAllFiles
                    ? 'Hiç dosya bulunamadı'
                    : 'PDF dosyası bulunamadı'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _connectAndList,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenile'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _uploadTestPdf,
                  icon: const Icon(Icons.upload),
                  label: const Text('Test PDF Yükle'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _connectAndList(),
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final isPdf = file.name.toLowerCase().endsWith('.pdf');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                    color: isPdf ? Colors.red : Colors.grey,
                    size: 36,
                  ),
                  title: Text(
                    file.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Boyut: ${file.sizeFormatted}' +
                        (file.modifyTime != null
                            ? '\nTarih: ${file.modifyTime!.toLocal()}'
                            : ''),
                  ),
                  isThreeLine: file.modifyTime != null,
                  trailing: isPdf
                      ? IconButton(
                          icon: const Icon(Icons.download, color: Colors.blue),
                          onPressed: () => _downloadAndOpenPdf(file),
                          tooltip: 'İndir ve Aç',
                        )
                      : const Icon(Icons.block, color: Colors.grey),
                  onTap: isPdf ? () => _downloadAndOpenPdf(file) : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _connectAndList() async {
    setState(() => _isLoading = true);

    ref.read(ftpConfigProvider.notifier).state = FtpConfig(
      host: _host,
      username: _username,
      password: _password,
      directory: _directory,
      port: _port,
    );

    ref.invalidate(ftpFilesProvider);

    setState(() => _isLoading = false);
  }

  Future<void> _uploadTestPdf() async {
    try {
      final testPdfBytes = await _createTestPdf();
      final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.pdf';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Test PDF yükleniyor...'),
            ],
          ),
        ),
      );

      final success = await FtpPdfLoader.uploadPdfToFtp(
        host: _host,
        username: _username,
        password: _password,
        pdfBytes: testPdfBytes,
        fileName: fileName,
      );

      if (mounted) {
        Navigator.pop(context);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Test PDF yüklendi: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
          _connectAndList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF yüklenemedi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<Uint8List> _createTestPdf() async {
    final pdf = sf.PdfDocument();
    final page = pdf.pages.add();

    page.graphics.drawString(
      'Test PDF - ${DateTime.now()}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 30),
      bounds: const Rect.fromLTWH(50, 100, 400, 50),
    );

    final bytes = await pdf.save();
    pdf.dispose();
    return Uint8List.fromList(bytes);
  }

  Future<void> _downloadAndOpenPdf(FtpFile file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text('${file.name} indiriliyor...'),
            ),
          ],
        ),
      ),
    );

    try {
      final loader = FtpPdfLoader(
        host: _host,
        username: _username,
        password: _password,
        filePath: file.path,
        port: _port,
      );

      await ref.read(pdfProvider.notifier).loadPdf(loader);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF yüklenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
