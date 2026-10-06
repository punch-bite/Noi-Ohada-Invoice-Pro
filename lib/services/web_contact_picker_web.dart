import 'dart:js_interop';

@JS('window.navigator.contacts')
external _ContactsApi? get _contactsApi;

@JS()
@staticInterop
class _ContactsApi {}

extension on _ContactsApi {
  external JSPromise<JSArray<JSAny?>> select(
    JSArray<JSString> properties,
  );
}

@JS()
@staticInterop
class _BrowserContact {}

extension on _BrowserContact {
  external JSArray<JSString>? get name;
  external JSArray<JSString>? get tel;
  external JSArray<JSString>? get email;
}

String _first(JSArray<JSString>? values) {
  if (values == null || values.toDart.isEmpty) return '';
  return values.toDart.first.toDart;
}

Future<List<Map<String, String>>?> pickWebContacts() async {
  final contactsApi = _contactsApi;
  if (contactsApi == null) return null;

  try {
    final selected = await contactsApi.select(
      <JSString>['name'.toJS, 'tel'.toJS, 'email'.toJS].toJS,
    ).toDart;
    return selected.toDart.map((rawContact) {
      final contact = rawContact as _BrowserContact;
      return <String, String>{
        'name': _first(contact.name),
        'phone': _first(contact.tel),
        'email': _first(contact.email),
        'address': '',
      };
    }).toList();
  } catch (_) {
    return <Map<String, String>>[];
  }
}
