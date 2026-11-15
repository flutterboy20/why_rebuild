final RegExp _providerScope = RegExp(r'^_InheritedProviderScope<(.+?)\??>$');

/// Turns private framework/library type names into names a developer
/// recognises, e.g. `_InheritedProviderScope<CartModel?>` -> `Provider<CartModel>`.
String friendlyType(String type) {
  final RegExpMatch? m = _providerScope.firstMatch(type);
  if (m != null) {
    return 'Provider<${m.group(1)}>';
  }
  return switch (type) {
    '_InheritedTheme' => 'Theme',
    '_LocalizationsScope' => 'Localizations',
    '_UncontrolledProviderScope' ||
    'UncontrolledProviderScope' =>
      'Riverpod ProviderScope',
    _ => type,
  };
}
