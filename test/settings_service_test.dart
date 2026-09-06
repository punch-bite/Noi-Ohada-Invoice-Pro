// test/settings_service_test.dart
//
// 🧪 Garde-fou du bug « les modifications de facture personnalisée ne sont
// pas enregistrées » : vérifie que `SettingsService` persiste réellement
// les `InvoiceSettings` dans la box Hive `invoice_settings` et les recharge.
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_settings.dart';
import 'package:noi_ohada_invoice_pro/services/hive_service.dart';
import 'package:noi_ohada_invoice_pro/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveService.initForTest();
  });

  test('loadSettings retourne les valeurs par défaut au premier appel',
      () async {
    // Box vide au premier lancement.
    final s = await SettingsService.instance.loadSettings();
    expect(s, isA<InvoiceSettings>());
    expect(s.showLogo, isTrue);
    expect(s.watermarkText, isNotEmpty);
  });

  test('saveSettings persiste et loadSettings recharge les valeurs', () async {
    final service = SettingsService.instance;

    final modified = InvoiceSettings(
      showWatermark: true,
      watermarkText: 'MA SOCIÉTÉ SARL',
      primaryColor: const Color(0xFF123456),
      textColor: const Color(0xFF222222),
      fontFamily: 'WorkSans',
      fontSize: 13.5,
      showPaymentQR: true,
    );

    await service.saveSettings(modified);

    // 🔄 Recharge depuis la persistance (Hive) : les modifications DOIVENT
    // être retrouvées — c'est exactement le bug corrigé.
    final reloaded = await service.loadSettings();
    expect(reloaded.showWatermark, isTrue);
    expect(reloaded.watermarkText, 'MA SOCIÉTÉ SARL');
    expect(reloaded.primaryColor, const Color(0xFF123456));
    expect(reloaded.textColor, const Color(0xFF222222));
    expect(reloaded.fontFamily, 'WorkSans');
    expect(reloaded.fontSize, 13.5);
    expect(reloaded.showPaymentQR, isTrue);
  });

  test('updateSettings applique les changements et persiste', () async {
    final service = SettingsService.instance;

    final updated = await service.updateSettings(
        (current) => current.copyWith(showBorder: false, showLogo: false));

    expect(updated.showBorder, isFalse);
    expect(updated.showLogo, isFalse);

    final reloaded = await service.loadSettings();
    expect(reloaded.showBorder, isFalse);
    expect(reloaded.showLogo, isFalse);
  });

  test('resetSettings restaure les valeurs par défaut', () async {
    final service = SettingsService.instance;
    await service.saveSettings(InvoiceSettings(
      showWatermark: true,
      watermarkText: 'TEMP',
    ));

    final reset = await service.resetSettings();
    expect(reset.watermarkText, InvoiceSettings.defaultSettings.watermarkText);
    expect(reset.showWatermark, isFalse);

    final reloaded = await service.loadSettings();
    expect(reloaded.watermarkText,
        InvoiceSettings.defaultSettings.watermarkText);
  });
}
