import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/provider/pdf_provider.dart';
import 'package:signature/signature.dart';

class SignatureDialog extends ConsumerStatefulWidget {
  final int pageIndex;
  final int signatureIndex;

  const SignatureDialog({
    required this.pageIndex,
    required this.signatureIndex,
  });

  @override
  ConsumerState<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends ConsumerState<SignatureDialog> {
  late final SignatureController _controller;
  late final String _key;

  @override
  void initState() {
    super.initState();
    _key = '${widget.pageIndex}_${widget.signatureIndex}';
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(pdfProvider.notifier);

    return AlertDialog(
      title: Text('İmza ${widget.signatureIndex + 1}'),
      content: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: Signature(
          controller: _controller,
          backgroundColor: Colors.transparent,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _controller.clear();
            notifier.clearSignature(_key);
            Navigator.pop(context);
          },
          child: const Text('Temizle'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () async {
            final signature = await _controller.toPngBytes();
            if (signature != null) {
              notifier.updateSignature(_key, signature);
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
