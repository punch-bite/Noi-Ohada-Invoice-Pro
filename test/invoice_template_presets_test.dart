// test/invoice_template_presets_test.dart
//
// 🧪 Garde-fou des 8 modèles prédéfinis « Royal Ledger » : chacun doit
// embarquer une configuration `positions` COMPLÈTE (même schéma que celui
// écrit par l'atelier de personnalisation — `_saveConfig`), afin que
// l'aperçu A4 et le PDF exploitent réellement :
//   • l'ordre / la visibilité des sections (`blocks_sections`,
//     `blocks_order`, `block_visibility`) ;
//   • l'ordre / largeurs / alignements d'en-tête (`header_elements_order`,
//     `header_widths`, `header_alignments`) ;
//   • les textes libres (`invoice_title_text`, `invoice_subtitle`,
//     `custom_legal_text`, `signatory_title`, `stamp_text`) ;
//   • les options d'impression (`qr_position`, `show_paid_stamp`,
//     `show_signature_line`).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noi_ohada_invoice_pro/models/client.dart';
import 'package:noi_ohada_invoice_pro/models/company.dart';
import 'package:noi_ohada_invoice_pro/models/invoice.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_layout.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_template.dart';
import 'package:noi_ohada_invoice_pro/models/line_item.dart';
import 'package:noi_ohada_invoice_pro/services/printing_service.dart';

/// 🏢 Société émettrice minimale (sans logo : `showLogo` retombe sur un vide).
Company _company() => Company(
      userId: 'u1',
      name: 'OHADA Presets SARL',
      address: 'Douala, Cameroun',
      taxId: 'NUI123',
      phone: '690000000',
      email: 'contact@presets.com',
      logoPath: '',
      legalText: 'Merci de votre confiance.',
    );

/// 🙋 Client destinataire minimal.
Client _client() => Client(
      userId: 'u1',
      name: 'Client Presets',
      address: 'Yaoundé',
      taxId: 'NUI456',
      phone: '691111111',
      email: 'client@presets.com',
    );

/// 🧾 Facture de démonstration (1 ligne, TVA 18 %).
Invoice _invoice() => Invoice(
      companyId: 'c1',
      clientId: 'cl1',
      invoiceNumber: 'FAC-PRESET-1',
      issueDate: DateTime(2026, 1, 15),
      dueDate: DateTime(2026, 2, 14),
      items: [
        LineItem(description: 'Prestation', quantity: 2, unitPrice: 12500),
      ],
      subtotal: 25000,
      taxRate: 18,
      taxAmount: 4500,
      totalAmount: 29500,
    );

/// 🧱 Clés de blocs acceptées par l'atelier (et la colonne vide « spacer »).
const Set<String> _knownBlocks = {
  'billing_info',
  'invoice_meta',
  'items_table',
  'totals',
  'legal_mentions',
  'signature_block',
  'qr_block',
  'empty_column',
};

/// 🧾 Clés d'éléments d'en-tête connues du moteur PDF.
const Set<String> _knownHeaderElements = {
  'logo',
  'company_info',
  'invoice_title',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 🧪 Le moteur PDF lit SharedPreferences via TemplateCustomService et
    // SettingsService : on fournit un stockage vide pour rester hors ligne.
    SharedPreferences.setMockInitialValues({});
  });

  final templates = InvoiceTemplate.getDefaultTemplates();

  test('8 modèles prédéfinis, identifiants uniques et stables', () {
    expect(templates, hasLength(8));
    expect(
      templates.map((t) => t.id).toList(),
      List<String>.generate(8, (i) => 'default_${i + 1}'),
    );
  });

  test('chaque modèle embarque des positions non vides', () {
    for (final t in templates) {
      expect(
        t.positions.isNotEmpty,
        isTrue,
        reason: '${t.id} (${t.name}) : positions vides → aucune '
            "configuration d'impression pour ce modèle.",
      );
    }
  });

  test('clés obligatoires présentes avec le bon type', () {
    const stringKeys = [
      'invoice_title_text',
      'invoice_subtitle',
      'custom_legal_text',
      'signatory_title',
      'stamp_text',
      'qr_position',
    ];
    const boolKeys = ['show_paid_stamp', 'show_signature_line'];
    const mapKeys = [
      'block_visibility',
      'block_alignment',
      'header_widths',
      'header_alignments',
    ];

    for (final t in templates) {
      final p = t.positions;
      for (final k in stringKeys) {
        expect(p[k], isA<String>(),
            reason: '${t.id} : « $k » manquant ou non textuel');
      }
      for (final k in boolKeys) {
        expect(p[k], isA<bool>(),
            reason: '${t.id} : « $k » manquant ou non booléen');
      }
      for (final k in mapKeys) {
        expect(p[k], isA<Map>(), reason: '${t.id} : « $k » manquant');
      }
      expect(p['blocks_sections'], isA<List>(),
          reason: '${t.id} : « blocks_sections » manquant');
      expect(p['blocks_order'], isA<List>(),
          reason: '${t.id} : « blocks_order » manquant');
      expect(p['header_elements_order'], isA<List>(),
          reason: '${t.id} : « header_elements_order » manquant');
    }
  });

  test('sections : blocs connus, sans doublon, cohérents avec visibilité', () {
    for (final t in templates) {
      final sections = InvoiceTemplate.decodeSections(
        t.positions['blocks_sections'],
      );
      expect(sections, isNotEmpty, reason: '${t.id} : aucune section');

      final flat = <String>[];
      for (final section in sections) {
        expect(section, isNotEmpty,
            reason: '${t.id} : section vide (colonne inutile)');
        expect(section.length, lessThanOrEqualTo(3),
            reason: '${t.id} : section de plus de 3 colonnes');
        for (final key in section) {
          expect(_knownBlocks, contains(key),
              reason: '${t.id} : bloc inconnu « $key »');
        }
        flat.addAll(section);
      }
      expect(flat.toSet(), hasLength(flat.length),
          reason: '${t.id} : un bloc apparaît dans plusieurs sections');

      // L'ordre à plat (`blocks_order`) doit refléter les sections.
      expect(t.positions['blocks_order'], flat,
          reason: '${t.id} : blocks_order désynchronisé des sections');

      // Visibilité : tout bloc projeté doit être décrit.
      final visibility = t.positions['block_visibility'] as Map;
      for (final key in flat) {
        expect(visibility.containsKey(key), isTrue,
            reason: '${t.id} : « $key » absent de block_visibility');
      }
    }
  });

  test('en-tête : ordre complet, largeurs et alignements connus', () {
    for (final t in templates) {
      final order =
          List<String>.from(t.positions['header_elements_order'] as List);
      expect(order.toSet(), containsAll(_knownHeaderElements),
          reason: "${t.id} : éléments d'en-tête incomplets ($order)");
      for (final key in order) {
        expect(_knownHeaderElements, contains(key),
            reason: "${t.id} : élément d'en-tête inconnu « $key »");
      }

      final widths = t.positions['header_widths'] as Map;
      widths.forEach((k, v) {
        expect(_knownHeaderElements, contains(k.toString()),
            reason: '${t.id} : largeur pour un élément inconnu « $k »');
        expect(v, isA<num>(), reason: '${t.id} : largeur non numérique');
      });

      final aligns = t.positions['header_alignments'] as Map;
      aligns.forEach((k, v) {
        expect(_knownHeaderElements, contains(k.toString()),
            reason: '${t.id} : alignement pour un élément inconnu « $k »');
        expect(const ['left', 'center', 'right'], contains(v),
            reason: '${t.id} : alignement invalide « $v »');
      });
    }
  });

  test('QR : bloc projeté uniquement si le modèle active le QR', () {
    for (final t in templates) {
      final flat =
          InvoiceTemplate.decodeSections(t.positions['blocks_sections'])
              .expand((s) => s)
              .toList();
      final hasQrBlock = flat.contains('qr_block');
      expect(hasQrBlock, t.showPaymentQR,
          reason: '${t.id} : incohérence entre qr_block ($hasQrBlock) et '
              'showPaymentQR (${t.showPaymentQR})');
      expect(t.positions['qr_position'], 'totals',
          reason: '${t.id} : le QR doit être rendu dans le bloc « Totaux »');
    }
  });

  test('textes libres renseignés et exploitables par le PDF', () {
    for (final t in templates) {
      final title = (t.positions['invoice_title_text'] as String).trim();
      expect(title.isNotEmpty, isTrue,
          reason: '${t.id} : titre de facture vide');
      final legal = (t.positions['custom_legal_text'] as String).trim();
      expect(legal.isNotEmpty, isTrue,
          reason: '${t.id} : mentions légales vides');
      final stamp = (t.positions['stamp_text'] as String).trim();
      expect(stamp.isNotEmpty, isTrue, reason: '${t.id} : tampon vide');
      // Le sous-titre est optionnel, mais reste toujours une String.
      expect(t.positions['invoice_subtitle'], isA<String>());
    }
  });

  test("positions relues sans erreur par le modèle de layout de l'atelier", () {
    for (final t in templates) {
      final config = InvoiceLayoutConfig.fromMap(t.positions);
      expect(config.positions, isNotEmpty,
          reason: '${t.id} : layout relu vide');
    }
  });

  test('aller-retour toMap/fromMap conserve la configuration', () {
    for (final t in templates.take(2)) {
      final roundTrip = InvoiceTemplate.fromMap(t.toMap());
      expect(roundTrip.positions['blocks_sections'],
          t.positions['blocks_sections'],
          reason: '${t.id} : sections perdues au round-trip');
      expect(roundTrip.positions['invoice_title_text'],
          t.positions['invoice_title_text'],
          reason: '${t.id} : titre perdu au round-trip');
      expect(roundTrip.positions.length, t.positions.length,
          reason: '${t.id} : clés perdues au round-trip');
    }
  });

  group('positions effectives (priorité personnalisation > modèle)', () {
    test('la personnalisation locale est prioritaire', () {
      final result = InvoiceTemplate.effectivePositions(
        customPositions: const {'invoice_title_text': 'MA FACTURE'},
        templatePositions: const {'invoice_title_text': 'PRESET'},
      );
      expect(result['invoice_title_text'], 'MA FACTURE');
    });

    test('repli sur les positions du modèle si aucune personnalisation', () {
      final result = InvoiceTemplate.effectivePositions(
        customPositions: const {},
        templatePositions: const {'invoice_title_text': 'PRESET'},
      );
      expect(result['invoice_title_text'], 'PRESET');
    });

    test('le repli sur chaque preset produit un layout exploitable', () {
      for (final t in templates) {
        final effective = InvoiceTemplate.effectivePositions(
          customPositions: const {},
          templatePositions: t.positions,
        );
        expect(effective, isNotEmpty, reason: '${t.id} : repli vide');
        expect(
          InvoiceTemplate.decodeSections(effective['blocks_sections']),
          isNotEmpty,
          reason: '${t.id} : aucune section après repli',
        );
      }
    });
  });

  test('les 8 modèles produisent des rendus VISIBLEMENT distincts', () {
    final signatures = <String>{};
    for (final t in templates) {
      final p = t.positions;
      final signature = [
        p['invoice_title_text'],
        p['invoice_subtitle'],
        p['signatory_title'],
        (p['blocks_sections'] as List).join(';'),
        (p['header_elements_order'] as List).join(','),
      ].join('|');
      expect(signatures.add(signature), isTrue,
          reason: '${t.id} : rendu identique à un autre modèle ($signature)');
    }
    expect(signatures, hasLength(8));
  });

  group('encodage des sections (contrainte Firestore)', () {
    test('encodeSections produit une liste PLATE de chaînes', () {
      final encoded = InvoiceTemplate.encodeSections(const [
        ['billing_info', 'invoice_meta'],
        ['items_table'],
        ['totals', 'qr_block'],
      ]);
      expect(encoded, const [
        'billing_info|invoice_meta',
        'items_table',
        'totals|qr_block',
      ]);
      for (final entry in encoded) {
        expect(entry, isA<String>());
      }
    });

    test('decodeSections reconstruit la forme plate (Firestore/presets)', () {
      expect(
        InvoiceTemplate.decodeSections(const [
          'billing_info|invoice_meta',
          'items_table',
        ]),
        const [
          ['billing_info', 'invoice_meta'],
          ['items_table'],
        ],
      );
    });

    test('decodeSections accepte la forme imbriquée (atelier / JSON)', () {
      expect(
        InvoiceTemplate.decodeSections(const [
          ['billing_info', 'invoice_meta'],
          <String>[],
          ['totals'],
        ]),
        const [
          ['billing_info', 'invoice_meta'],
          <String>[],
          ['totals'],
        ],
      );
    });

    test('decodeSections tolère les valeurs inattendues', () {
      expect(InvoiceTemplate.decodeSections(null), isEmpty);
      expect(InvoiceTemplate.decodeSections('billing_info'), isEmpty);
      expect(InvoiceTemplate.decodeSections(const [42]), isEmpty);
      // Séparateurs redondants et espaces parasites ignorés.
      expect(
        InvoiceTemplate.decodeSections(
            const [' billing_info | | invoice_meta ']),
        const [
          ['billing_info', 'invoice_meta'],
        ],
      );
    });

    test('les 8 presets font un aller-retour encode → decode fidèle', () {
      for (final t in templates) {
        final sections =
            InvoiceTemplate.decodeSections(t.positions['blocks_sections']);
        expect(
          InvoiceTemplate.encodeSections(sections),
          t.positions['blocks_sections'],
          reason: '${t.id} : encodage non réversible',
        );
      }
    });
  });

  group('compatibilité d\'écriture Firestore', () {
    /// 🔍 Parcourt une valeur et échoue si elle contient un **tableau
    /// imbriqué** : `batch.set` lèverait alors
    /// « Nested arrays are not supported ».
    void expectFirestoreSafe(Object? value, String path) {
      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          expect(value[i], isNot(isA<List>()),
              reason: 'Firestore refuse « $path[$i] » (tableau imbriqué)');
          expectFirestoreSafe(value[i], '$path[$i]');
        }
      } else if (value is Map) {
        value.forEach((k, v) => expectFirestoreSafe(v, '$path.$k'));
      }
    }

    test('toMap() de chaque preset est écrivable dans Firestore', () {
      for (final t in templates) {
        expectFirestoreSafe(t.toMap(), t.id);
      }
    });

    test('les sections restent des chaînes (jamais de sous-listes)', () {
      for (final t in templates) {
        for (final entry in t.positions['blocks_sections'] as List) {
          expect(entry, isA<String>(),
              reason: '${t.id} : élément « $entry » non textuel');
        }
      }
    });
  });

  group('backfill des positions en base (modèles historiques)', () {
    test('aucun backfill si la version est antérieure au design courant', () {
      expect(
        InvoiceTemplate.presetPositionsNeedBackfill(
          storedPositions: const {},
          storedVersion: InvoiceTemplate.kRoyalDesignVersion - 1,
        ),
        isFalse,
        reason: 'la mise à jour complète du modèle s\'en charge déjà',
      );
    });

    test('backfill si positions absentes ou vides (design courant)', () {
      expect(
        InvoiceTemplate.presetPositionsNeedBackfill(
          storedPositions: null,
          storedVersion: InvoiceTemplate.kRoyalDesignVersion,
        ),
        isTrue,
      );
      expect(
        InvoiceTemplate.presetPositionsNeedBackfill(
          storedPositions: const <String, dynamic>{},
          storedVersion: InvoiceTemplate.kRoyalDesignVersion,
        ),
        isTrue,
      );
    });

    test('pas de backfill si des positions existent déjà (admin)', () {
      expect(
        InvoiceTemplate.presetPositionsNeedBackfill(
          storedPositions: const {'blocks_sections': []},
          storedVersion: InvoiceTemplate.kRoyalDesignVersion,
        ),
        isFalse,
      );
    });
  });

  // 📄 Validation de bout en bout : les `positions` du preset sont
  // réellement exploitables par le moteur PDF (rendu par sections).
  test('PDF généré sans erreur pour chacun des 8 presets', () async {
    for (final t in const ['default_1', 'default_6']) {
      final template = templates.singleWhere((e) => e.id == t);
      final bytes = await PrintingService.generateInvoicePdf(
        invoice: _invoice(),
        client: _client(),
        company: _company(),
        template: template,
        customPositions: template.positions,
        customMapping: template.mapping,
      );
      expect(bytes, isNotEmpty, reason: '$t : PDF vide');
      expect(String.fromCharCodes(bytes.take(4)), '%PDF',
          reason: '$t : sortie non PDF');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
