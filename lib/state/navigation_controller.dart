import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { library, create, discover, community }

class NavigationController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.library;

  void select(AppTab tab) => state = tab;
}

final navigationProvider = NotifierProvider<NavigationController, AppTab>(
  NavigationController.new,
);
