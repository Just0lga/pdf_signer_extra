import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ftp_pdf_loader.dart';
import '../models/ftp_file.dart';

final ftpConfigProvider = StateProvider<FtpConfig>((ref) => FtpConfig(
      host: '192.168.137.253',
      username: 'tolga',
      password: '1234',
      directory: '/',
      port: 21,
    ));

final ftpFilesProvider = FutureProvider<List<FtpFile>>((ref) async {
  final config = ref.watch(ftpConfigProvider);
  return await FtpPdfLoader.listPdfFiles(
    host: config.host,
    username: config.username,
    password: config.password,
    directory: config.directory,
    port: config.port,
  );
});

class FtpConfig {
  final String host;
  final String username;
  final String password;
  final String directory;
  final int port;

  FtpConfig({
    required this.host,
    required this.username,
    required this.password,
    this.directory = '/',
    this.port = 21,
  });

  FtpConfig copyWith({
    String? host,
    String? username,
    String? password,
    String? directory,
    int? port,
  }) =>
      FtpConfig(
        host: host ?? this.host,
        username: username ?? this.username,
        password: password ?? this.password,
        directory: directory ?? this.directory,
        port: port ?? this.port,
      );
}
