import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // Eklendi
import 'screens/pdf_imza_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null); // Türkçe tarih formatı için
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PDF İmza',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: PdfImzaScreen(),
      );
}
