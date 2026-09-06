// test/settings_template_fusion_test.dart
//
// 🧪 Teste la fusion InvoiceSettings → InvoiceTemplate : les personnali-
// sations globales OVERRIDENT le modèle SEULEMENT si elles diffèrent des
// défauts ; sinon le design propre du modèle est conservé.
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_settings.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_template.dart';
import 'package:noi_ohada_invoice_pro/services/settings_service.dart';

void main() {
  // Modèle « premium » avec son propre design.
  final template = InvoiceTemplate(
    id: 't1',
    name: 'Charbon',
    description: 'Design premium',
    primaryColor: const Color(0xFF0B0E14),
    textColor: const Color(0xFFF5F5F5),
    backgroundColor: const Color(0xFF0B0E14),
    fontFamily: 'WorkSans',
    fontSize: 12.5,
    showLogo: true,
    showBorder: false,
    showTaxDetails: true,
    showPaymentTerms: true,
    showPaymentQR: true,
  );

  test('settings par défaut → le design du modèle est conservé', () {
    final effective =
        SettingsService.applyToTemplate(template, InvoiceSettings.defaultSettings);

    // Aucune surcharge : tout le design du modèle reste intact.
    expect(effective.primaryColor, template.primaryColor);
    expect(effective.textColor, template.textColor);
    expect(effective.backgroundColor, template.backgroundColor);
    expect(effective.fontFamily, template.fontFamily);
    expect(effective.fontSize, template.fontSize);
    expect(effective.showBorder, template.showBorder);
    expect(effective.showPaymentQR, template.showPaymentQR);
    // Identité préservée (pas de mutation).
    expect(effective.id, template.id);
  });

  test('couleur primaire personnalisée → override sur le modèle', () {
    final custom = InvoiceSettings(primaryColor: const Color(0xFF123456));
    final effective = SettingsService.applyToTemplate(template, custom);

    expect(effective.primaryColor, const Color(0xFF123456));
    // Les autres propriétés du modèle ne bougent pas.
    expect(effective.textColor, template.textColor);
    expect(effective.backgroundColor, template.backgroundColor);
    expect(effective.fontFamily, template.fontFamily);
  });

  test('police/taille personnalisées → override ; toggles → override', () {
    final custom = InvoiceSettings(
      fontFamily: 'Manrope',
      fontSize: 14.0,
      showBorder: true,
      showPaymentQR: false,
      showLogo: false,
    );
    final effective = SettingsService.applyToTemplate(template, custom);

    expect(effective.fontFamily, 'Manrope');
    expect(effective.fontSize, 14.0);
    // showBorder : défaut setting = true, modèle = false → l'utilisateur n'a
    // PAS modifié (défaut) → on garde le modèle (false).
    expect(effective.showBorder, template.showBorder);
    // showPaymentQR : setting false = défaut → modèle true conservé.
    expect(effective.showPaymentQR, template.showPaymentQR);
    // showLogo : setting false ≠ défaut true → override.
    expect(effective.showLogo, isFalse);
  });

  test('couleur de fond + texte personnalisés → page et texte réstylés', () {
    final custom = InvoiceSettings(
      backgroundColor: const Color(0xFFFFFBF0),
      textColor: const Color(0xFF101010),
    );
    final effective = SettingsService.applyToTemplate(template, custom);

    expect(effective.backgroundColor, const Color(0xFFFFFBF0));
    expect(effective.textColor, const Color(0xFF101010));
    expect(effective.primaryColor, template.primaryColor);
  });
}
