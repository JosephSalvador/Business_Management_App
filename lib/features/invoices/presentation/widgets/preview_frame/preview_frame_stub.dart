import 'package:flutter/material.dart';

import 'preview_frame_platform.dart';

export 'preview_frame_platform.dart';

class DocumentPreviewFrameStub implements DocumentPreviewFramePlatform {
  @override
  Widget buildFrame({
    required BuildContext context,
    required String? htmlContent,
    required bool isThermal,
    required bool isLoading,
  }) {
    final double targetWidth = isThermal ? 320 : double.infinity;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: targetWidth,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isThermal ? 4 : 8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isThermal ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            width: isThermal ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (htmlContent == null || htmlContent.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Hakuna muonekano wa kiolezo kwa sasa.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isThermal ? 12 : 24,
                  vertical: 20,
                ),
                child: _RawHtmlFallbackViewer(
                  html: htmlContent,
                  isThermal: isThermal,
                ),
              ),
            if (isLoading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> printDocument(String? htmlContent) async {
    // Non-web platform print fallback
  }
}

class _RawHtmlFallbackViewer extends StatelessWidget {
  const _RawHtmlFallbackViewer({
    required this.html,
    required this.isThermal,
  });

  final String html;
  final bool isThermal;

  @override
  Widget build(BuildContext context) {
    // Extracts visible text elements cleanly for quick native visual feedback
    final stripped = html
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isThermal ? Icons.receipt_long : Icons.description_outlined,
                  size: 16,
                  color: const Color(0xFF0D9488),
                ),
                const SizedBox(width: 6),
                Text(
                  isThermal ? 'POS Tape (80mm Thermal)' : 'A4 Standard Preview',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        Text(
          stripped,
          style: TextStyle(
            fontSize: isThermal ? 11 : 13,
            height: 1.5,
            color: const Color(0xFF1E293B),
            fontFamily: isThermal ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

DocumentPreviewFramePlatform createDocumentPreviewFrame() =>
    DocumentPreviewFrameStub();
