import 'package:flutter/material.dart';

class AppState extends InheritedWidget {
  const AppState({super.key, required super.child});

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppState>()!;
  }

  @override
  bool updateShouldNotify(AppState oldWidget) => false;
}
