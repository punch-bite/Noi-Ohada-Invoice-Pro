import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_settings.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_template.dart';
import 'package:noi_ohada_invoice_pro/services/invoice_render_service.dart';
import 'package:noi_ohada_invoice_pro/services/template_custom_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('workspace settings persist and resolve over the selected preset', () async {
    final preset = InvoiceTemplate(
      id: 'preset-test',
      name: 'Preset test',
      description: 'Preset for persistence regression',
      mapping: const {'client_name': 'client_name'},
      positions: const {
        'blocks_sections': ['billing_info', 'signature_block'],
        'header_sections': [
          ['logo', 'company_info'],
          ['invoice_title'],
        ],
        'block_visibility': {'signature_block': true},
        'header_style': 'band',
      },
    );
    final workspacePositions = <String, dynamic>{
      'blocks_sections': [
        ['items_table'],
        ['signature_block'],
      ],
      'header_sections': [
        ['company_info'],
        ['invoice_title', 'logo'],
      ],
      'block_visibility': {'signature_block': true},
      'block_alignment': {'signature_block': 'right'},
      'signature_image': 'c2lnbmF0dXJl',
      'header_style': 'dark',
      'custom_font_size': 17.0,
      'block_fonts': {'signature_block': 'Manrope'},
      'block_font_scales': {'signature_block': 1.4},
      'template_overrides': {
        'primaryColorValue': 0xFF123456,
        'showLogo': false,
        'fontFamily': 'Manrope',
      },
    };
    const mapping = {'client_name': 'company_name'};
    const background = TemplateBackgroundSettings(presetId: 'indigo-nuit');

    await Future.wait([
      TemplateCustomService.saveCustom(
        preset.id,
        positions: workspacePositions,
        mapping: mapping,
        background: background,
      ),
      TemplateCustomService.saveCustom(
        preset.id,
        positions: workspacePositions,
        mapping: mapping,
        background: background,
      ),
    ]);

    final saved = await TemplateCustomService.loadCustom(preset.id);
    final render = await InvoiceRenderService.resolveRenderState(
      template: preset,
      invoiceSettings: InvoiceSettings.defaultSettings,
    );

    expect(saved.positions['header_sections'], workspacePositions['header_sections']);
    expect(saved.positions['blocks_sections'], workspacePositions['blocks_sections']);
    expect(saved.positions['signature_image'], 'c2lnbmF0dXJl');
    expect(saved.background.presetId, 'indigo-nuit');
    expect(saved.mapping, mapping);
    expect(render.positions['header_style'], 'dark');
    expect(render.positions['block_alignment'], {'signature_block': 'right'});
    expect(render.effectiveTemplate.fontSize, 17.0);
    expect(render.positions['block_fonts'], {'signature_block': 'Manrope'});
    expect(render.positions['block_font_scales'], {'signature_block': 1.4});
    expect(render.effectiveTemplate.primaryColorValue, 0xFF123456);
    expect(render.effectiveTemplate.showLogo, isFalse);
    expect(render.effectiveTemplate.fontFamily, 'Manrope');
    expect(render.mapping['client_name'], 'company_name');
    expect(render.backgroundSettings.presetId, 'indigo-nuit');
  });
}
