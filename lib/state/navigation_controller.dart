import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { scanner, library, community }

class NavigationController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.scanner;

  void select(AppTab tab) => state = tab;
}

final navigationProvider = NotifierProvider<NavigationController, AppTab>(
  NavigationController.new,
);
