import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/provider/ftp_provider.dart';
import 'package:pdf_signer_extra/provider/pdf_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../models/ftp_file.dart';
import '../services/ftp_pdf_loader.dart';

class FtpBrowserScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<FtpBrowserScreen> createState() => _FtpBrowserScreenState();
}

class _FtpBrowserScreenState extends ConsumerState<FtpBrowserScreen> {
  final String _host = '192.168.137.253';
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

  // Dosyaları tarihe göre sırala (en yeni önce)
  List<FtpFile> _sortFilesByDate(List<FtpFile> files) {
    final sortedFiles = List<FtpFile>.from(files);

    sortedFiles.sort((a, b) {
      // Eğer her iki dosyanın da modifyTime'ı varsa
      if (a.modifyTime != null && b.modifyTime != null) {
        return b.modifyTime!.compareTo(a.modifyTime!); // Yeniden eskiye doğru
      }
      // Eğer sadece a'nın modifyTime'ı varsa, a önce gelir
      else if (a.modifyTime != null && b.modifyTime == null) {
        return -1;
      }
      // Eğer sadece b'nin modifyTime'ı varsa, b önce gelir
      else if (a.modifyTime == null && b.modifyTime != null) {
        return 1;
      }
      // Eğer ikisinin de modifyTime'ı yoksa, dosya adına göre sırala
      else {
        return a.name.compareTo(b.name);
      }
    });

    return sortedFiles;
  }

  // Dosya adından imza indexlerini çıkar
  Set<int> getSignatureIndexesFromFileName(String fileName) {
    final Set<int> indexes = <int>{};

    // .pdf uzantısını kaldır
    String baseName = fileName.toLowerCase().endsWith('.pdf')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;

    // _imzalandi_ varsa indexleri çıkar
    if (baseName.contains('_imzalandi_')) {
      final index = baseName.indexOf('_imzalandi_');
      final indexPart = baseName.substring(index + '_imzalandi_'.length);

      // Her karakteri kontrol et (örn: "12" → [1, 2])
      for (int i = 0; i < indexPart.length; i++) {
        final digit = int.tryParse(indexPart[i]);
        if (digit != null && digit >= 1 && digit <= 4) {
          indexes.add(digit);
        }
      }
    }

    return indexes;
  }

  // İmza kutularını oluştur
  Widget _buildSignatureBoxes(FtpFile file) {
    final signedIndexes = getSignatureIndexesFromFileName(file.name);

    return FittedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) {
          final signatureNumber = index + 1;
          final isSigned = signedIndexes.contains(signatureNumber);

          return Container(
            margin: EdgeInsets.all(4),
            width: 70,
            height: 20,
            decoration: BoxDecoration(
              color: isSigned ? Colors.green[200] : Colors.red[200],
              border: Border.all(
                color: isSigned ? Colors.green : Colors.red,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '$signatureNumber',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSigned ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP PDF Listesi',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.blue,
        centerTitle: true,
        actions: [
          /*
          IconButton(
            icon: Icon(_showAllFiles ? Icons.folder : Icons.picture_as_pdf),
            onPressed: () {
              setState(() {
                _showAllFiles = !_showAllFiles;
              });
              _connectAndList();
            },
            tooltip: _showAllFiles ? 'Sadece PDF' : 'Tüm Dosyalar',
          ),*/
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
            color: Colors.blue.withOpacity(0.1),
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
                // Sıralama bilgisi ekle
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.sort, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Dosyalar tarihe göre sıralandı (En yeni önce)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                /*Text(
                  _showAllFiles
                      ? 'Tüm Dosyalar Gösteriliyor'
                      : 'Sadece PDF Dosyaları',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),*/
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
          return const Center(
              child: CircularProgressIndicator(
            color: Colors.blue,
          ));
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

        final rawFiles = snapshot.data ?? [];
        final files =
            _sortFilesByDate(rawFiles); // Dosyaları tarihe göre sırala

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
          color: Colors.blue,
          onRefresh: () async => _connectAndList(),
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final isPdf = file.name.toLowerCase().endsWith('.pdf');

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    // Kenar çizgisi
                    color: Colors.blue, // Çizgi rengi
                  ),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      /*Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                        color: isPdf ? Colors.red : Colors.grey,
                        size: 36,
                      ),*/

                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Boyut: ${file.sizeFormatted}',
                                  style: TextStyle(color: Colors.blue),
                                ),
                                if (file.modifyTime != null)
                                  Text(
                                    'Tarih: ${DateFormat('d MMMM y HH:mm', 'tr_TR').format(file.modifyTime!.add(Duration(hours: 3)))}',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Icon(
                              Icons.picture_as_pdf,
                              color: Colors.blue,
                              size: 36,
                            ),
                          )
                        ],
                      ),
                      isThreeLine: file.modifyTime != null,
                      onTap: isPdf ? () => _downloadAndOpenPdf(file) : null,
                    ),
                    // PDF dosyalarında imza kutularını göster
                    if (isPdf) _buildSignatureBoxes(file),
                    const SizedBox(height: 8),
                  ],
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
              CircularProgressIndicator(
                color: Colors.blue,
              ),
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

      if (context.mounted) {
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
      if (context.mounted) {
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
    // Loading dialog'unu göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${file.name} indiriliyor...'),
                  const SizedBox(height: 8),
                  Text(
                    'Boyut: ${file.sizeFormatted}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // FTP loader'ı oluştur
      final loader = FtpPdfLoader(
        host: _host,
        username: _username,
        password: _password,
        filePath: file.path,
        port: _port,
      );

      // PDF'i yükle
      await ref.read(pdfProvider.notifier).loadPdf(
            loader,
            fileName: file.name,
          );

      // PDF yükleme başarılı
      if (context.mounted) {
        Navigator.pop(context); // Loading dialog
        Navigator.pop(context); // FtpBrowserScreen

        // Başarı mesajı
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} başarıyla yüklendi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('PDF yükleme hatası: $e');

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'unu kapat

        // Hata mesajını göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PDF yüklenemedi: ${file.name}'),
                const SizedBox(height: 4),
                Text(
                  'Hata: $e',
                  style: TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _downloadAndOpenPdf(file),
            ),
          ),
        );
      }
    }
  }
}
