import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/providers/locale_provider.dart';

extension I18nContextX on BuildContext {
  bool get isArabic => watch<LocaleProvider>().isArabic;

  String tr({required String en, required String ar}) {
    return isArabic ? ar : en;
  }
}

