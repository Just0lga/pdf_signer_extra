// widgets/pdf_page_widget.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_signer_extra/models/pdf_state.dart';
import 'package:pdf_signer_extra/provider/pdf_notifier.dart';

class PdfPageWidget extends ConsumerStatefulWidget {
  final int pageIndex;
  final Function(int) onSignatureTap;

  const PdfPageWidget({
    Key? key,
    required this.pageIndex,
    required this.onSignatureTap,
  }) : super(key: key);

  @override
  ConsumerState<PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends ConsumerState<PdfPageWidget> {
  Future<Uint8List?>? _renderFuture;

  @override
  void initState() {
    super.initState();
    // Init'de future'ı bir kez oluştur
    _renderFuture = ref.read(pdfProvider.notifier).renderPage(widget.pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfProvider);

    return FutureBuilder<Uint8List?>(
      future: _renderFuture,
      builder: (context, snapshot) {
        Widget pageContent;

        if (snapshot.connectionState == ConnectionState.waiting) {
          pageContent = _buildLoadingContent(state);
        } else if (snapshot.hasError) {
          pageContent = _buildErrorContent();
        } else if (snapshot.hasData && snapshot.data != null) {
          pageContent = _buildRenderedContent(snapshot.data!, state);
        } else {
          pageContent = _buildEmptyContent();
        }

        return Container(
          margin: const EdgeInsets.all(10),
          decoration: _boxDecoration(),
          child: Stack(
            children: [
              pageContent,
              if (snapshot.hasData) _buildSignatureRow(state),
              _buildPageNumber(),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      );

  Widget _buildLoadingContent(PdfState state) {
    final pageSize = state.pageSizes[widget.pageIndex];
    if (pageSize == null)
      return const Center(child: CircularProgressIndicator());

    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        width: pageSize.width,
        height: pageSize.height,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorContent() => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Sayfa yüklenemedi', style: TextStyle(color: Colors.red)),
        ),
      );

  Widget _buildEmptyContent() => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Boş sayfa'),
        ),
      );

  Widget _buildRenderedContent(Uint8List imageData, PdfState state) {
    final pageSize = state.pageSizes[widget.pageIndex];
    if (pageSize == null) return const SizedBox();

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: pageSize.width,
        height: pageSize.height,
        child: Image.memory(
          imageData,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildSignatureRow(PdfState state) {
    final pageSize = state.pageSizes[widget.pageIndex];
    if (pageSize == null) return const SizedBox();

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (signatureIndex) {
            final key = '${widget.pageIndex}_$signatureIndex';
            final hasSignature = state.signatures.containsKey(key) &&
                state.signatures[key] != null;

            return Flexible(
              child: GestureDetector(
                onTap: state.isLoading
                    ? null
                    : () => widget.onSignatureTap(signatureIndex),
                child: _buildSignatureBox(
                    key, hasSignature, signatureIndex, state, pageSize),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSignatureBox(
      String key, bool hasSignature, int index, PdfState state, Size pageSize) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: pageSize.height * 0.05,
      width: pageSize.width * 0.2,
      decoration: BoxDecoration(
        border: Border.all(
          color: hasSignature ? Colors.green : Colors.red,
          width: 2,
        ),
        color:
            state.isLoading ? Colors.grey.withOpacity(0.3) : Colors.transparent,
      ),
      child: hasSignature
          ? Padding(
              padding: const EdgeInsets.all(2),
              child: Image.memory(state.signatures[key]!, fit: BoxFit.contain),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit,
                      size: 16,
                      color: state.isLoading ? Colors.grey : Colors.red),
                  Text(
                    'İmza ${index + 1}',
                    style: TextStyle(
                        fontSize: 9,
                        color: state.isLoading ? Colors.grey : Colors.red),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPageNumber() => Positioned(
        top: 10,
        right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: Colors.black54,
          child: Text(
            'Sayfa ${widget.pageIndex + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
}
