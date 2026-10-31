import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/document_template.dart';

class TemplateMarketplaceGrid extends StatelessWidget {
  const TemplateMarketplaceGrid({
    super.key,
    required this.templates,
    required this.selectedTemplateId,
    required this.onTemplateSelected,
    this.primaryColor = const Color(0xFF0F172A),
  });

  final List<DocumentTemplateSummary> templates;
  final String selectedTemplateId;
  final ValueChanged<DocumentTemplateSummary> onTemplateSelected;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Hakuna violezo vilivyopatikana.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 550 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: templates.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final tpl = templates[index];
            final isSelected = tpl.id == selectedTemplateId;

            return _TemplateCard(
              template: tpl,
              isSelected: isSelected,
              primaryColor: primaryColor,
              onTap: () => onTemplateSelected(tpl),
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  final DocumentTemplateSummary template;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  Uint8List? _decodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      var clean = base64Str;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeBase64(template.thumbnailBase64);
    final isThermal = template.isThermal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF0D9488).withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview Visual Thumbnail
              Expanded(
                child: Container(
                  color: isThermal
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFF8FAFC),
                  child: Stack(
                    children: [
                      if (imageBytes != null)
                        Center(
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _DefaultIllustration(
                              isThermal: isThermal,
                              color: primaryColor,
                            ),
                          ),
                        )
                      else
                        _DefaultIllustration(
                          isThermal: isThermal,
                          color: primaryColor,
                        ),

                      // Badges overlay
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Row(
                          children: [
                            if (isThermal)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.receipt,
                                        size: 10, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '80mm POS Slip',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'A4 Standard',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ),
                            if (template.isDefault) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Selected check indicator
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D9488),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Title & Description
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFF0D9488)
                            : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (template.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        template.description!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultIllustration extends StatelessWidget {
  const _DefaultIllustration({
    required this.isThermal,
    required this.color,
  });

  final bool isThermal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (isThermal) {
      return Center(
        child: Container(
          width: 75,
          height: 100,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 28, height: 4, color: color),
              const SizedBox(height: 4),
              Container(width: 44, height: 2, color: const Color(0xFFE2E8F0)),
              const Divider(height: 8, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 20, height: 2, color: const Color(0xFF94A3B8)),
                  Container(width: 14, height: 2, color: const Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 24, height: 2, color: const Color(0xFF94A3B8)),
                  Container(width: 12, height: 2, color: const Color(0xFF94A3B8)),
                ],
              ),
              const Spacer(),
              Container(
                width: 22,
                height: 22,
                color: const Color(0xFF0F172A),
                child: const Center(
                  child: Icon(Icons.qr_code, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: 110,
        height: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 20, height: 6, color: color),
                Container(width: 32, height: 4, color: const Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: const Color(0xFFE2E8F0)),
            const SizedBox(height: 6),
            Container(height: 5, color: color.withOpacity(0.15)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Container(height: 3, color: const Color(0xFFF1F5F9))),
                const SizedBox(width: 4),
                Container(width: 14, height: 3, color: const Color(0xFFE2E8F0)),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(child: Container(height: 3, color: const Color(0xFFF1F5F9))),
                const SizedBox(width: 4),
                Container(width: 14, height: 3, color: const Color(0xFFE2E8F0)),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(width: 28, height: 5, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
