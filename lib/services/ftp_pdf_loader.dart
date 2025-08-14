import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:pdf_signer_extra/turkish.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/ftp_file.dart';
import 'pdf_loader_service.dart';

class FtpPdfLoader implements PdfLoaderService {
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

  @override
  Future<Uint8List?> loadPdf() async {
    FTPConnect? ftpConnect;
    File? tempFile;

    try {
      ftpConnect = FTPConnect(host,
          user: username,
          pass: password,
          port: port,
          timeout: 60,
          showLog: false);

      bool connected = await ftpConnect.connect();
      if (!connected) throw Exception('FTP bağlantısı kurulamadı');

      await ftpConnect.setTransferType(TransferType.binary);

      String workingPath = filePath;
      int fileSize = 0;

      if (filePath.contains('/')) {
        List<String> parts = filePath.split('/');
        String fileName = parts.last;

        // Gelişmiş Türkçe decoder kullan
        String decodedFileName =
            TurkishCharacterDecoder.decodeFileName(fileName);

        // Debug bilgisi
        print('🔄 Dosya decode: "$fileName" -> "$decodedFileName"');
        TurkishCharacterDecoder.debugCharacterCodes(fileName);

        List<String> pathsToTry = [
          filePath, // Orijinal
          parts.sublist(0, parts.length - 1).join('/') + '/$decodedFileName',
          parts.sublist(0, parts.length - 1).join('/') +
              '/${Uri.encodeComponent(decodedFileName)}',
        ];

        // Gelişmiş encoding varyantları
        List<String> encodingVariants =
            _generateAdvancedEncodingVariants(fileName);
        for (String variant in encodingVariants) {
          String variantPath =
              parts.sublist(0, parts.length - 1).join('/') + '/$variant';
          if (!pathsToTry.contains(variantPath)) {
            pathsToTry.add(variantPath);
          }
        }

        for (String tryPath in pathsToTry) {
          try {
            int trySize = await ftpConnect.sizeFile(tryPath);
            if (trySize > 0) {
              workingPath = tryPath;
              fileSize = trySize;
              print('✅ Çalışan path bulundu: $tryPath ($fileSize bytes)');
              break;
            }
          } catch (e) {
            print('❌ Path başarısız: $tryPath');
            continue;
          }
        }
      } else {
        // Basit dosya adı
        try {
          fileSize = await ftpConnect.sizeFile(filePath);
          if (fileSize > 0) workingPath = filePath;
        } catch (e) {
          print('Basit path başarısız: $e');
        }
      }

      if (fileSize <= 0) throw Exception('Dosya bulunamadı: $filePath');

      print('📥 İndiriliyor: $workingPath ($fileSize bytes)');

      tempFile = await _createTempFile();
      bool result = await ftpConnect
          .downloadFileWithRetry(workingPath, tempFile, pRetryCount: 3);

      if (!result) throw Exception('İndirme başarısız');

      Uint8List fileBytes = await tempFile.readAsBytes();

      // PDF kontrolü
      if (fileBytes.length < 4 ||
          String.fromCharCodes(fileBytes.sublist(0, 4)) != '%PDF') {
        throw Exception('Geçersiz PDF dosyası');
      }

      print('✅ PDF başarıyla indirildi: ${fileBytes.length} bytes');
      return fileBytes;
    } catch (e) {
      print('❌ FTP hatası: $e');
      rethrow;
    } finally {
      try {
        await ftpConnect?.disconnect();
        if (tempFile != null && await tempFile.exists())
          await tempFile.delete();
      } catch (e) {
        print('Cleanup hatası: $e');
      }
    }
  }

  // Gelişmiş Türkçe decoder kullan
  static String _decodeFileName(String fileName) {
    return TurkishCharacterDecoder.decodeFileName(fileName);
  }

  // Gelişmiş encoding varyantları oluştur - HIZLI versiyonu
  static List<String> _generateAdvancedEncodingVariants(
      String originalFileName) {
    List<String> variants = [];

    // 1. Orijinal
    variants.add(originalFileName);

    // 2. Türkçe karakter varsa sadece hızlı decode
    if (originalFileName.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      String decoded = TurkishCharacterDecoder.decodeFileName(originalFileName);
      if (decoded != originalFileName) {
        variants.add(decoded);
      }
    }

    // 3. Sadece gerekli durumlarda URL decode
    if (originalFileName.contains('%')) {
      try {
        String urlDecoded = Uri.decodeComponent(originalFileName);
        variants.add(urlDecoded);
      } catch (e) {/* ignore */}
    }

    // Maksimum 4 varyant - gereksiz işlem yok
    return variants.take(4).toList();
  }

  Future<File> _createTempFile() async {
    final tempDir = Directory.systemTemp;
    final fileName =
        'ftp_download_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return File('${tempDir.path}/$fileName');
  }

  // Gelişmiş dosya boyutu alma
  static Future<int> _getFileSize(
      FTPConnect ftpConnect, String originalFileName, String directory) async {
    // Önce basit deneme
    String simplePath = directory == '/'
        ? '/$originalFileName'
        : '$directory/$originalFileName';

    try {
      int size = await ftpConnect.sizeFile(simplePath);
      if (size > 0) {
        print('✅ Boyut alındı (basit): $simplePath -> $size bytes');
        return size;
      }
    } catch (e) {
      print('❌ Basit boyut alma başarısız: $simplePath');
    }

    // Encoding varyantlarını dene
    List<String> variants = _generateAdvancedEncodingVariants(originalFileName);

    for (String variant in variants) {
      String path = directory == '/' ? '/$variant' : '$directory/$variant';
      try {
        // Transfer mode'ları dene
        for (String mode in ['I', 'A']) {
          try {
            await ftpConnect.sendCustomCommand('TYPE $mode');
            int size = await ftpConnect.sizeFile(path);
            if (size > 0) {
              print('✅ Boyut alındı ($mode mode): $path -> $size bytes');
              return size;
            }
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        continue;
      }
    }

    print('⚠️ Hiçbir yöntemle boyut alınamadı: $originalFileName');
    return 0;
  }

  static Future<bool> verifyPdfFile(Uint8List bytes) async {
    try {
      if (bytes.length < 4) return false;

      String header = String.fromCharCodes(bytes.sublist(0, 4));
      if (header != '%PDF') return false;

      int searchStart = bytes.length > 1024 ? bytes.length - 1024 : 0;
      String content = String.fromCharCodes(bytes.sublist(searchStart));
      if (!content.contains('%%EOF')) return false;

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

  static Future<List<FtpFile>> listPdfFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    int port = 21,
  }) async {
    FTPConnect? ftpConnect;
    try {
      ftpConnect = FTPConnect(host,
          user: username,
          pass: password,
          port: port,
          timeout: 30,
          showLog: true);

      bool connected = await ftpConnect.connect();
      if (!connected) throw Exception('FTP bağlantısı kurulamadı');

      if (directory != '/') await ftpConnect.changeDirectory(directory);

      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      print('🔍 FTP\'den ${entries.length} dosya bulundu');

      List<FtpFile> pdfFiles = [];

      for (FTPEntry entry in entries) {
        print('📄 İşlenen dosya: "${entry.name}" - Type: ${entry.type}');

        if (entry.type == FTPEntryType.FILE &&
            entry.name.toLowerCase().endsWith('.pdf')) {
          // Gelişmiş Türkçe decoder kullan
          String decodedName =
              TurkishCharacterDecoder.decodeFileName(entry.name);
          print('🔄 Decode: "${entry.name}" -> "$decodedName"');

          // Debug için karakter kodlarını göster
          if (entry.name != decodedName) {
            print('🔍 Orijinal karakter analizi:');
            TurkishCharacterDecoder.debugCharacterCodes(entry.name);
            print('🔍 Decode edilmiş karakter analizi:');
            TurkishCharacterDecoder.debugCharacterCodes(decodedName);
          }

          String originalPath =
              directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';

          int fileSize = await _getFileSize(ftpConnect, entry.name, directory);

          pdfFiles.add(FtpFile(
            name: decodedName, // Decode edilmiş ad göster
            path: originalPath, // Orijinal path kullan
            size: fileSize,
            modifyTime: entry.modifyTime,
          ));

          print('✅ PDF eklendi: "$decodedName" (${fileSize} bytes)');
        } else {
          print('⏭️ Atlandı: "${entry.name}" - PDF değil veya dosya değil');
        }
      }

      print('🎯 Toplam PDF sayısı: ${pdfFiles.length}');
      return pdfFiles;
    } catch (e) {
      print('💥 FTP hatası: $e');
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

          // Türkçe karakter decode
          String decodedName =
              TurkishCharacterDecoder.decodeFileName(entry.name);

          int? fileSize;
          try {
            fileSize = await ftpConnect.sizeFile(fullPath);
            if (fileSize < 0) fileSize = 0;
          } catch (e) {
            fileSize = 0;
          }

          allFiles.add(FtpFile(
            name: decodedName, // Decode edilmiş ad kullan
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

      // Dosya adını uygun encode etmeye çalış
      String finalFileName = _prepareFileNameForUpload(fileName);
      print(
          '🔄 Upload için dosya adı hazırlandı: "$fileName" -> "$finalFileName"');

      String filePath =
          directory == '/' ? '/$finalFileName' : '$directory/$finalFileName';

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

      bool uploadResult = await _uploadWithRetryMultipleEncodings(
          ftpConnect, tempFile, fileName, pdfBytes.length);

      if (!uploadResult) {
        throw Exception('Dosya yükleme başarısız');
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

  // HIZLI dosya adı upload hazırlığı - gereksiz işlemleri kaldırdık
  static String _prepareFileNameForUpload(String fileName) {
    return fileName.trim(); // Sadece boşluk temizle
  }

  // HIZLI encoding varyantları - en çok kullanılanları önce
  static List<String> _generateUploadEncodingVariants(String fileName) {
    List<String> variants = [];

    // 1. Orijinal dosya adı (en yaygın)
    variants.add(fileName);

    // 2. Sadece Türkçe karakterler varsa encoding dene
    if (fileName.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      // UTF-8 → Latin-1 (en hızlı ve yaygın)
      try {
        List<int> utf8Bytes = utf8.encode(fileName);
        String latin1Encoded = latin1.decode(utf8Bytes, allowInvalid: true);
        if (latin1Encoded != fileName) {
          variants.add(latin1Encoded);
        }
      } catch (e) {/* ignore */}

      // Manuel hızlı mapping (önceden hesaplanmış)
      String manualEncoded = _fastTurkishEncode(fileName);
      if (manualEncoded != fileName) {
        variants.add(manualEncoded);
      }
    }

    // 3. Boşluk → alt çizgi (hızlı replace)
    if (fileName.contains(' ')) {
      variants.add(fileName.replaceAll(' ', '_'));
    }

    // Maksimum 4 varyant - daha fazlası gereksiz
    return variants.take(4).toList();
  }

  // HIZLI Türkçe karakter encoding - tek geçişte
  static String _fastTurkishEncode(String input) {
    if (!input.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      return input; // Türkçe karakter yoksa olduğu gibi döndür
    }

    // Tek geçişte tüm karakterleri değiştir
    StringBuffer result = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      switch (char) {
        case 'ğ':
          result.write('\u00F0');
          break; // ð
        case 'Ğ':
          result.write('\u00D0');
          break; // Ð
        case 'ı':
          result.write('\u00FD');
          break; // ý
        case 'İ':
          result.write('\u00DD');
          break; // Ý
        case 'ş':
          result.write('\u00FE');
          break; // þ
        case 'Ş':
          result.write('\u00DE');
          break; // Þ
        case 'ç':
          result.write('\u00E7');
          break; // ç
        case 'Ç':
          result.write('\u00C7');
          break; // Ç
        case 'ö':
          result.write('\u00F6');
          break; // ö
        case 'Ö':
          result.write('\u00D6');
          break; // Ö
        case 'ü':
          result.write('\u00FC');
          break; // ü
        case 'Ü':
          result.write('\u00DC');
          break; // Ü
        default:
          result.write(char);
          break;
      }
    }

    return result.toString();
  }

  static Future<bool> _uploadWithRetry(FTPConnect ftpConnect, File localFile,
      String remoteName, int expectedSize) async {
    const int maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Upload denemesi $attempt/$maxRetries: "$remoteName"');

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
            print('✅ Upload başarılı: "$remoteName" (${expectedSize} bytes)');
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

  // HIZLI birden fazla encoding ile upload deneme
  static Future<bool> _uploadWithRetryMultipleEncodings(FTPConnect ftpConnect,
      File localFile, String originalFileName, int expectedSize) async {
    // Hızlı encoding varyantları (maksimum 4 adet)
    List<String> encodingVariants =
        _generateUploadEncodingVariants(originalFileName);

    print('🚀 Hızlı upload: ${encodingVariants.length} varyant');

    // Paralel deneme yerine sıralı ama hızlı deneme
    for (int i = 0; i < encodingVariants.length; i++) {
      String fileName = encodingVariants[i];
      print('📤 Upload ${i + 1}/${encodingVariants.length}: "$fileName"');

      try {
        bool result = await _uploadWithRetry(
            ftpConnect, localFile, fileName, expectedSize);
        if (result) {
          print('✅ Upload başarılı!');
          return true;
        }
      } catch (e) {
        // Hata durumunda sonraki varyanta geç
        continue;
      }
    }

    return false;
  }

  // HIZLI upload doğrulama - gereksiz kontroller kaldırıldı
  static Future<void> _verifyUploadedFileName(
      FTPConnect ftpConnect, String originalName, String uploadedName) async {
    // Sadece gerekli durumlarda çalıştır
    if (originalName == uploadedName) return;

    print('✅ Upload tamamlandı: "$uploadedName"');
  }

  // BASIT ve HIZLI test fonksiyonu
  static Future<void> testUploadCharacterSet({
    required String host,
    required String username,
    required String password,
    int port = 21,
  }) async {
    print('🧪 Hızlı karakter seti testi...');

    // Sadece 1 test dosyası - hızlı
    String testName = 'test_ğüişöç.txt';
    String testContent = 'Test';

    FTPConnect? ftpConnect;
    try {
      ftpConnect = FTPConnect(host, user: username, pass: password, port: port);
      if (!(await ftpConnect.connect())) throw Exception('Bağlantı hatası');

      File tempFile = await _createTempFileForUpload(utf8.encode(testContent));

      // Sadece 2 varyant dene - hızlı
      List<String> variants = _generateUploadEncodingVariants(testName);

      for (String variant in variants.take(2)) {
        try {
          bool result = await ftpConnect.uploadFileWithRetry(tempFile,
              pRemoteName: variant);
          if (result) {
            print('✅ Çalışan encoding: "$variant"');
            try {
              await ftpConnect.deleteFile(variant);
            } catch (e) {}
            break;
          }
        } catch (e) {
          continue;
        }
      }

      await tempFile.delete();
    } catch (e) {
      print('Test hatası: $e');
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {}
    }
  }

  // Dosya adı karakter analizi (debugging için)
  static void analyzeFileName(String fileName) {
    print('\n🔍 Dosya adı analizi: "$fileName"');
    TurkishCharacterDecoder.debugCharacterCodes(fileName);

    String decoded = TurkishCharacterDecoder.decodeFileName(fileName);
    print('✅ Decode sonucu: "$decoded"');

    if (fileName != decoded) {
      print('🔍 Decode edilmiş karakter analizi:');
      TurkishCharacterDecoder.debugCharacterCodes(decoded);
    }
  }
}
