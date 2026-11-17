class TestHelper {
  static const String textInputKeyValue = 'intl_text_input_key';
  static const String dropdownButtonKeyValue = 'intl_dropdown_key';
  static const String countrySearchInputKeyValue = 'intl_search_input_key';
  static String Function(String? isoCode) countryItemKeyValue =
      (String? isoCode) => 'intl_country_${isoCode!.toUpperCase()}_key';
}
