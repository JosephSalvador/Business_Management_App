import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

class CustomOverrideField extends StatefulWidget {
  const CustomOverrideField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.isSwahili = false,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool isSwahili;

  @override
  State<CustomOverrideField> createState() => _CustomOverrideFieldState();
}

class _CustomOverrideFieldState extends State<CustomOverrideField> {
  late TextEditingController _controller;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant CustomOverrideField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomText = _controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCustomText ? AppColors.primary : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasCustomText
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.code,
                      size: 16,
                      color: hasCustomText
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isSwahili
                              ? 'Muundo Maalum wa Liquid / HTML'
                              : 'Custom Liquid / HTML Override',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          hasCustomText
                              ? (widget.isSwahili
                                  ? 'Kodi maalum imewashwa'
                                  : 'Custom layout override active')
                              : (widget.isSwahili
                                  ? 'Gusa kubinafsisha muundo'
                                  : 'Tap to write custom liquid tags'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: hasCustomText
                                ? AppColors.primary
                                : AppColors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.tertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LIQUID TEMPLATE EDITOR',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (hasCustomText)
                        InkWell(
                          onTap: () {
                            _controller.clear();
                            widget.onChanged('');
                          },
                          child: Text(
                            widget.isSwahili ? 'Futa' : 'Clear',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF87171),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    maxLines: 8,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFF8FAFC),
                      height: 1.45,
                    ),
                    cursorColor: const Color(0xFF38BDF8),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText:
                          '<!-- Custom Liquid Schema -->\n<div class="header">\n  <h1>{{ invoice.number }}</h1>\n</div>',
                      hintStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF475569),
                      ),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 14, color: AppColors.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.isSwahili
                          ? 'Kodi husafishwa kiotomatiki kuzuia script zenye madhara (XSS protection).'
                          : 'Sanitized on server to strip scripts and dangerous iframes automatically.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
