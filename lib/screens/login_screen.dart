import 'package:flutter/material.dart';
import 'package:pdf_signer_extra/screens/pdf_imza_screen.dart';
import 'package:pdf_signer_extra/widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Hoşgeldiniz",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF5fd8e7),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SizedBox(
              height: height * 0.04,
            ),
            Image.asset(
              "assets/logo.png",
              height: height * 0.3,
            ),
            SizedBox(height: height * 0.04),
            AppTextField(label: "Email", controller: usernameController),
            SizedBox(height: height * 0.02),
            AppTextField(label: "Şifre", controller: passwordController),
            SizedBox(height: height * 0.04),
            GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfImzaScreen(),
                    ));
              },
              child: Container(
                alignment: Alignment.center,
                width: width,
                height: height * 0.06,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Color(0xFF5fd8e7)),
                child: Text(
                  "Giriş Yap",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
