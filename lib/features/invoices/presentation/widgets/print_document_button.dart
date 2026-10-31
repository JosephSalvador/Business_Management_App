import 'package:flutter/material.dart';

import 'preview_frame/preview_frame.dart';

class PrintDocumentButton extends StatefulWidget {
  const PrintDocumentButton({
    super.key,
    required this.htmlContent,
    required this.isThermal,
    this.label = 'Chapisha Hati',
    this.icon = Icons.print_outlined,
  });

  final String? htmlContent;
  final bool isThermal;
  final String label;
  final IconData icon;

  @override
  State<PrintDocumentButton> createState() => _PrintDocumentButtonState();
}

class _PrintDocumentButtonState extends State<PrintDocumentButton> {
  bool _printing = false;

  Future<void> _handlePrint() async {
    if (_printing || widget.htmlContent == null || widget.htmlContent!.isEmpty) {
      return;
    }

    setState(() => _printing = true);

    try {
      await documentPreviewFrame.printDocument(widget.htmlContent);
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: (widget.htmlContent == null || _printing) ? null : _handlePrint,
      icon: _printing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(widget.isThermal ? Icons.receipt_long : widget.icon, size: 18),
      label: Text(
        _printing
            ? 'Inachapisha...'
            : (widget.isThermal ? 'Chapisha Risiti ya POS' : widget.label),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            widget.isThermal ? const Color(0xFF0F172A) : const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
