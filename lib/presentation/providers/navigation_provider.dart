import 'package:flutter_riverpod/legacy.dart';

final currentRouteProvider = StateProvider<String>((ref) => 'Dashboard');

typedef BackHandler = bool Function();

final backHandlerProvider = StateProvider<BackHandler?>((ref) => null);

final routeHistoryProvider = StateProvider<List<String>>((ref) => ['Dashboard']);
