import 'dart:typed_data';
import 'dart:io';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/ftp_file.dart';
import 'pdf_loader_service.dart'; // Interface'i import et

class FtpPdfLoader implements PdfLoaderService {
  // ✅ Interface'i implement et
  final String host;
  final String username;
  final String password;
  final String filePath;
  final int port;

  FtpPdfLoader({
    required this.host,
    required this.username,
    required this.password,
    required this.filePath,
    this.port = 21,
  });

  @override // ✅ Override annotation'ı ekle
  Future<Uint8List?> loadPdf() async {
    FTPConnect? ftpConnect;
    File? tempFile;

    try {
      // FTP bağlantısını kur
      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 60,
        showLog: false,
      );

      // Bağlantıyı aç
      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      // Binary modda indir (ÖNEMLİ: PDF dosyaları için binary mod şart)
      await ftpConnect.setTransferType(TransferType.binary);

      // Dosya boyutunu al
      int fileSize = await ftpConnect.sizeFile(filePath);
      if (fileSize <= 0) {
        throw Exception('Dosya bulunamadı veya boş: $filePath');
      }

      print('İndirilecek dosya boyutu: $fileSize bytes');

      // Geçici dosya oluştur
      tempFile = await _createTempFile();

      // Dosyayı retry mekanizması ile indir
      bool downloadResult =
          await _downloadWithRetry(ftpConnect, filePath, tempFile, fileSize);

      if (!downloadResult) {
        throw Exception('Dosya indirilemedi');
      }

      // Dosyayı byte array olarak oku
      Uint8List fileBytes = await tempFile.readAsBytes();

      // Dosya boyutu kontrolü
      if (fileBytes.length != fileSize) {
        print(
            'UYARI: Beklenen boyut: $fileSize, İndirilen boyut: ${fileBytes.length}');
        throw Exception(
            'Dosya tamamen indirilemedi. Beklenen: $fileSize, İndirilen: ${fileBytes.length}');
      }

      // PDF doğrulama
      bool isValidPdf = await verifyPdfFile(fileBytes);
      if (!isValidPdf) {
        throw Exception('İndirilen dosya geçerli bir PDF değil');
      }

      print(
          'Dosya başarıyla indirildi ve doğrulandı: ${fileBytes.length} bytes');
      return fileBytes;
    } catch (e) {
      print('FTP indirme hatası: $e');
      rethrow;
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }

      // Geçici dosyayı temizle
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('Geçici dosya silme hatası: $e');
      }
    }
  }

  // Geçici dosya oluştur
  Future<File> _createTempFile() async {
    final tempDir = Directory.systemTemp;
    final fileName =
        'ftp_download_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return File('${tempDir.path}/$fileName');
  }

  // Retry mekanizması ile indirme
  Future<bool> _downloadWithRetry(FTPConnect ftpConnect, String remotePath,
      File localFile, int expectedSize) async {
    const int maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('İndirme denemesi $attempt/$maxRetries');

        // Dosyayı indir
        bool result = await ftpConnect.downloadFileWithRetry(
          remotePath,
          localFile,
          pRetryCount: 2,
        );

        if (result) {
          // Dosya boyutu kontrolü
          if (await localFile.exists()) {
            int downloadedSize = await localFile.length();
            if (downloadedSize == expectedSize) {
              print('İndirme başarılı: $downloadedSize bytes');
              return true;
            } else {
              print(
                  'Boyut uyumsuzluğu - deneme $attempt: beklenen $expectedSize, alınan $downloadedSize');
            }
          }
        }
      } catch (e) {
        print('İndirme denemesi $attempt başarısız: $e');
        if (attempt == maxRetries) rethrow;
      }

      // Başarısız indirme durumunda dosyayı sil
      try {
        if (await localFile.exists()) {
          await localFile.delete();
        }
      } catch (e) {
        print('Geçici dosya silme hatası: $e');
      }

      // Kısa bir bekleme
      await Future.delayed(Duration(seconds: attempt));
    }

    return false;
  }

  // PDF dosya doğrulama fonksiyonu
  static Future<bool> verifyPdfFile(Uint8List bytes) async {
    try {
      // PDF header kontrolü
      if (bytes.length < 4) return false;

      String header = String.fromCharCodes(bytes.sublist(0, 4));
      if (header != '%PDF') return false;

      // PDF footer kontrolü (son 1024 byte'ta %%EOF arayalım)
      int searchStart = bytes.length > 1024 ? bytes.length - 1024 : 0;
      String content = String.fromCharCodes(bytes.sublist(searchStart));
      if (!content.contains('%%EOF')) return false;

      // Syncfusion PDF ile doğrulama
      try {
        final document = sf.PdfDocument(inputBytes: bytes);
        bool isValid = document.pages.count > 0;
        document.dispose();
        return isValid;
      } catch (e) {
        print('PDF doğrulama hatası: $e');
        return false;
      }
    } catch (e) {
      print('PDF doğrulama genel hatası: $e');
      return false;
    }
  }

  // Static metodlar (listeleme ve upload)
  static Future<List<FtpFile>> listPdfFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    int port = 21,
  }) async {
    FTPConnect? ftpConnect;
    try {
      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 30,
        showLog: false,
      );

      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      if (directory != '/') {
        await ftpConnect.changeDirectory(directory);
      }

      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      List<FtpFile> pdfFiles = [];

      for (FTPEntry entry in entries) {
        if (entry.type == FTPEntryType.FILE &&
            entry.name.toLowerCase().endsWith('.pdf')) {
          String fullPath =
              directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';

          int? fileSize;
          try {
            fileSize = await ftpConnect.sizeFile(fullPath);
            if (fileSize < 0) fileSize = 0;
          } catch (e) {
            print('Dosya boyutu alınamadı ${entry.name}: $e');
            fileSize = 0;
          }

          pdfFiles.add(FtpFile(
            name: entry.name,
            path: fullPath,
            size: fileSize ?? 0,
            modifyTime: entry.modifyTime,
          ));
        }
      }

      return pdfFiles;
    } catch (e) {
      print('FTP listeleme hatası: $e');
      throw Exception('Dosya listesi alınamadı: $e');
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }
    }
  }

  static Future<List<FtpFile>> listAllFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    int port = 21,
  }) async {
    FTPConnect? ftpConnect;
    try {
      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 30,
        showLog: false,
      );

      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      if (directory != '/') {
        await ftpConnect.changeDirectory(directory);
      }

      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      List<FtpFile> allFiles = [];

      for (FTPEntry entry in entries) {
        if (entry.type == FTPEntryType.FILE) {
          String fullPath =
              directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';

          int? fileSize;
          try {
            fileSize = await ftpConnect.sizeFile(fullPath);
            if (fileSize < 0) fileSize = 0;
          } catch (e) {
            fileSize = 0;
          }

          allFiles.add(FtpFile(
            name: entry.name,
            path: fullPath,
            size: fileSize ?? 0,
            modifyTime: entry.modifyTime,
          ));
        }
      }

      return allFiles;
    } catch (e) {
      print('FTP tüm dosya listeleme hatası: $e');
      throw Exception('Dosya listesi alınamadı: $e');
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }
    }
  }

  static Future<bool> uploadPdfToFtp({
    required String host,
    required String username,
    required String password,
    required Uint8List pdfBytes,
    required String fileName,
    String directory = '/',
    int port = 21,
    bool overwrite = false,
  }) async {
    FTPConnect? ftpConnect;
    File? tempFile;

    try {
      bool isValidPdf = await verifyPdfFile(pdfBytes);
      if (!isValidPdf) {
        throw Exception('Geçersiz PDF dosyası');
      }

      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 120,
        showLog: false,
      );

      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      if (directory != '/') {
        await ftpConnect.changeDirectory(directory);
      }

      await ftpConnect.setTransferType(TransferType.binary);

      String filePath =
          directory == '/' ? '/$fileName' : '$directory/$fileName';

      if (!overwrite) {
        try {
          int existingSize = await ftpConnect.sizeFile(filePath);
          if (existingSize >= 0) {
            throw Exception('Dosya zaten mevcut');
          }
        } catch (e) {
          // Dosya yoksa normal, devam et
        }
      }

      tempFile = await _createTempFileForUpload(pdfBytes);

      bool uploadResult = await _uploadWithRetry(
          ftpConnect, tempFile, fileName, pdfBytes.length);

      if (!uploadResult) {
        throw Exception('Dosya yükleme başarısız');
      }

      await Future.delayed(Duration(seconds: 1));

      int uploadedSize = await ftpConnect.sizeFile(filePath);
      if (uploadedSize < 0 || uploadedSize != pdfBytes.length) {
        print(
            'UYARI: Yüklenen dosya boyutu eşleşmiyor. Beklenen: ${pdfBytes.length}, Yüklenen: $uploadedSize');
        try {
          await ftpConnect.deleteFile(filePath);
        } catch (e) {
          print('Bozuk dosya silinemedi: $e');
        }
        throw Exception('Yüklenen dosya boyutu eşleşmiyor');
      }

      print('Dosya başarıyla yüklendi: $fileName (${pdfBytes.length} bytes)');
      return true;
    } catch (e) {
      print('FTP upload hatası: $e');
      return false;
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }

      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('Geçici dosya silme hatası: $e');
      }
    }
  }

  static Future<File> _createTempFileForUpload(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final fileName = 'ftp_upload_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  static Future<bool> _uploadWithRetry(FTPConnect ftpConnect, File localFile,
      String remoteName, int expectedSize) async {
    const int maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Upload denemesi $attempt/$maxRetries');

        bool result = await ftpConnect.uploadFileWithRetry(
          localFile,
          pRemoteName: remoteName,
          pRetryCount: 2,
        );

        if (result) {
          await Future.delayed(Duration(milliseconds: 500));

          String remotePath = '/$remoteName';
          int uploadedSize = await ftpConnect.sizeFile(remotePath);
          if (uploadedSize >= 0 && uploadedSize == expectedSize) {
            return true;
          } else {
            print(
                'Upload deneme $attempt: boyut uyumsuzluğu - beklenen $expectedSize, yüklenen $uploadedSize');
            try {
              await ftpConnect.deleteFile(remotePath);
            } catch (e) {
              print('Bozuk dosya silinemedi: $e');
            }
          }
        }
      } catch (e) {
        print('Upload denemesi $attempt başarısız: $e');
        if (attempt == maxRetries) rethrow;
      }

      await Future.delayed(Duration(seconds: attempt));
    }

    return false;
  }
}
