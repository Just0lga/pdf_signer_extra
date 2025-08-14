import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    bool isPasswordField = widget.label == "Şifre";

    return TextField(
      controller: widget.controller,
      keyboardType: widget.label == "Email"
          ? TextInputType.emailAddress
          : TextInputType.text,
      obscureText: isPasswordField ? _obscurePassword : false,
      cursorColor: Color(0xFF5fd8e7),
      cursorHeight: 24,
      cursorWidth: 2,
      autofocus: false,
      maxLines: 1,
      textInputAction:
          widget.label == "Email" ? TextInputAction.next : TextInputAction.done,
      style: const TextStyle(color: Color(0xFF5fd8e7)),
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: GoogleFonts.poppins(
          color: Color(0xFF5fd8e7),
          fontSize: 16,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(color: Color(0xFF5fd8e7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(color: Color(0xFF5fd8e7)),
        ),
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Color(0xFF5fd8e7),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
      ),
    );
  }
}
