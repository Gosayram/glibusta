import 'package:flutter/widgets.dart';

extension ContextExtensions on BuildContext {
  Future<T?> pushNamed<T>(String name, {Object? extra}) {
    return Navigator.of(this).pushNamed<T>(name, arguments: extra);
  }

  void pop<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }
}

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}