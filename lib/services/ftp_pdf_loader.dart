import 'dart:typed_data';
import 'dart:io';
import 'package:ftpconnect/ftpconnect.dart';
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
    try {
      final ftpConnect = FTPConnect(
        host,
        port: port,
        user: username,
        pass: password,
      );

      await ftpConnect.connect();

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await ftpConnect.downloadFile(filePath, tempFile);
      final fileBytes = await tempFile.readAsBytes();
      await tempFile.delete();
      await ftpConnect.disconnect();

      return fileBytes;
    } catch (e) {
      print('FTP bağlantı hatası: $e');
      return null;
    }
  }

  static Future<List<FtpFile>> listPdfFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    int port = 21,
  }) async {
    try {
      final ftpConnect = FTPConnect(
        host,
        port: port,
        user: username,
        pass: password,
      );

      print('FTP Bağlanıyor: $host');
      await ftpConnect.connect();
      print('FTP Bağlantı başarılı');

      if (directory != '/' && directory.isNotEmpty) {
        await ftpConnect.changeDirectory(directory);
      }

      final files = await ftpConnect.listDirectoryContent();
      print('Toplam dosya/klasör sayısı: ${files.length}');

      for (var file in files) {
        print('Dosya: ${file.name}, Tip: ${file.type}, Boyut: ${file.size}');
      }

      final pdfFiles = files
          .where((file) =>
              file.type == FTPEntryType.FILE &&
              file.name.toLowerCase().endsWith('.pdf'))
          .map((file) => FtpFile(
                name: file.name,
                size: file.size ?? 0,
                modifyTime: file.modifyTime,
                path: directory +
                    (directory.endsWith('/') ? '' : '/') +
                    file.name,
              ))
          .toList();

      print('Bulunan PDF sayısı: ${pdfFiles.length}');

      await ftpConnect.disconnect();
      return pdfFiles;
    } catch (e) {
      print('FTP listeleme hatası detay: $e');
      return [];
    }
  }

  static Future<List<FtpFile>> listAllFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    int port = 21,
  }) async {
    try {
      final ftpConnect = FTPConnect(host,
          port: port, user: username, pass: password, showLog: true);

      await ftpConnect.connect();

      if (directory != '/' && directory.isNotEmpty) {
        await ftpConnect.changeDirectory(directory);
      }

      final files = await ftpConnect.listDirectoryContent();

      final allFiles = files
          .where((file) => file.type == FTPEntryType.FILE)
          .map((file) => FtpFile(
                name: file.name,
                size: file.size ?? 0,
                modifyTime: file.modifyTime,
                path: directory +
                    (directory.endsWith('/') ? '' : '/') +
                    file.name,
              ))
          .toList();

      await ftpConnect.disconnect();
      return allFiles;
    } catch (e) {
      print('FTP listeleme hatası: $e');
      return [];
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
  }) async {
    try {
      final ftpConnect = FTPConnect(
        host,
        port: port,
        user: username,
        pass: password,
      );

      await ftpConnect.connect();

      if (directory != '/' && directory.isNotEmpty) {
        await ftpConnect.changeDirectory(directory);
      }

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/temp_upload_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      bool result = await ftpConnect.uploadFile(
        tempFile,
        sRemoteName: fileName,
      );

      await tempFile.delete();
      await ftpConnect.disconnect();

      return result;
    } catch (e) {
      print('Upload hatası: $e');
      return false;
    }
  }
}
