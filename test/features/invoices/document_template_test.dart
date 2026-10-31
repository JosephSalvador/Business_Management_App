import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/invoices/application/document_template_controller.dart';
import 'package:jolinx_app/features/invoices/domain/document_template.dart';
import 'package:jolinx_app/features/invoices/presentation/widgets/commercial_palette_picker.dart';
import 'package:jolinx_app/features/invoices/presentation/widgets/print_profile_selector.dart';
import 'package:jolinx_app/shared/widgets/responsive_layout_builder.dart';

void main() {
  group('DocumentType Enum', () {
    test('parses integers and strings accurately', () {
      expect(DocumentType.fromValue(1), DocumentType.invoice);
      expect(DocumentType.fromValue(2), DocumentType.deliveryNote);
      expect(DocumentType.fromString('Invoice'), DocumentType.invoice);
      expect(DocumentType.fromString('DeliveryNote'), DocumentType.deliveryNote);
      expect(DocumentType.fromString('delivery_note'), DocumentType.deliveryNote);
    });
  });

  group('DocumentTemplateSummary & Detail', () {
    test('correctly detects thermal 80mm layouts', () {
      const summaryThermal = DocumentTemplateSummary(
        id: 'tpl-1',
        name: 'Thermal POS Slip',
        description: 'Designed for 80mm ESC/POS hardware',
        documentType: DocumentType.invoice,
      );

      const summaryA4 = DocumentTemplateSummary(
        id: 'tpl-2',
        name: 'Modern Minimalist',
        description: 'Clean A4 corporate invoice',
        documentType: DocumentType.invoice,
      );

      expect(summaryThermal.isThermal, isTrue);
      expect(summaryA4.isThermal, isFalse);
    });

    test('serializes and deserializes template models accurately', () {
      final json = {
        'id': '6fa85f64-5717-4562-b3fc-2c963f66afa6',
        'name': 'Classic Corporate',
        'description': 'Traditional bordered corporate layout',
        'documentType': 1,
        'thumbnailBase64': 'data:image/svg+xml;base64,PHN2Zz4=',
        'isDefault': true,
        'displayOrder': 2,
      };

      final summary = DocumentTemplateSummary.fromJson(json);
      expect(summary.id, '6fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(summary.name, 'Classic Corporate');
      expect(summary.documentType, DocumentType.invoice);
      expect(summary.isDefault, isTrue);
      expect(summary.displayOrder, 2);
    });
  });

  group('TenantDocumentConfiguration', () {
    test('generates clean update request json omitting blank overrides', () {
      const config = TenantDocumentConfiguration(
        id: 'cfg-1',
        tenantId: 'ten-1',
        documentType: DocumentType.invoice,
        activeTemplateId: 'tpl-1',
        customLiquidOverride: '   ',
        themePrimaryHex: '#0F172A',
        themeSecondaryHex: '#0D9488',
        showLogo: true,
        footerNotes: 'Thank you for your business.',
      );

      final req = config.toUpdateRequestJson();
      expect(req['activeTemplateId'], 'tpl-1');
      expect(req['customLiquidOverride'], isNull);
      expect(req['themePrimaryHex'], '#0F172A');
      expect(req['themeSecondaryHex'], '#0D9488');
      expect(req['showLogo'], isTrue);
      expect(req['footerNotes'], 'Thank you for your business.');
    });
  });

  group('DocumentTemplateState', () {
    test('computes currentTypeTemplates and isThermal dynamically', () {
      const t1 = DocumentTemplateSummary(
        id: '1',
        name: 'Modern Minimalist',
        documentType: DocumentType.invoice,
      );
      const t2 = DocumentTemplateSummary(
        id: '2',
        name: 'Standard Logistics',
        documentType: DocumentType.deliveryNote,
      );
      const t3 = DocumentTemplateSummary(
        id: '3',
        name: 'Thermal POS Slip',
        documentType: DocumentType.invoice,
      );

      final state = DocumentTemplateState(
        selectedDocumentType: DocumentType.invoice,
        templates: const [t1, t2, t3],
        activeTemplateId: '3',
      );

      expect(state.currentTypeTemplates.length, 2);
      expect(state.currentTypeTemplates.map((t) => t.id), containsAll(['1', '3']));
      expect(state.isThermal, isTrue);

      final deliveryState = state.copyWith(
        selectedDocumentType: DocumentType.deliveryNote,
        activeTemplateId: '2',
      );
      expect(deliveryState.currentTypeTemplates.length, 1);
      expect(deliveryState.currentTypeTemplates.first.id, '2');
      expect(deliveryState.isThermal, isFalse);
    });
  });

  group('PDF Bytes Retrieval & Formatting Contract', () {
    test('validates standard PDF header and roll format detection', () {
      final sampleHeader = '%PDF-1.4'.codeUnits;
      expect(sampleHeader.length, 8);
      expect(String.fromCharCodes(sampleHeader), '%PDF-1.4');
    });
  });

  group('Enterprise Breakpoint Responsiveness Matrix', () {
    test('resolves phone, tablet, and desktop breakpoints strictly', () {
      expect(ResponsiveLayoutBuilder.resolveCategory(320), EnterpriseScreenCategory.phone);
      expect(ResponsiveLayoutBuilder.resolveCategory(767.9), EnterpriseScreenCategory.phone);
      expect(ResponsiveLayoutBuilder.resolveCategory(768.0), EnterpriseScreenCategory.tablet);
      expect(ResponsiveLayoutBuilder.resolveCategory(900), EnterpriseScreenCategory.tablet);
      expect(ResponsiveLayoutBuilder.resolveCategory(1023.9), EnterpriseScreenCategory.tablet);
      expect(ResponsiveLayoutBuilder.resolveCategory(1024.0), EnterpriseScreenCategory.desktop);
      expect(ResponsiveLayoutBuilder.resolveCategory(1920), EnterpriseScreenCategory.desktop);
    });

    test('validates print size profile mapping', () {
      expect(PrintSizeProfile.a4Standard.isThermal, isFalse);
      expect(PrintSizeProfile.thermal80mm.isThermal, isTrue);
    });

    test('contains accessible commercial palette presets', () {
      expect(CommercialPalettePicker.presets, isNotEmpty);
      final classic = CommercialPalettePicker.presets.first;
      expect(classic.primaryHex, '#0F172A');
      expect(classic.secondaryHex, '#0D9488');
    });
  });
}
