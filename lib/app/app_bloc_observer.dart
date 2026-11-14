import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    developer.log('${bloc.runtimeType} ← ${event.runtimeType}', name: 'bloc');
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    developer.log(
      '${bloc.runtimeType}: ${transition.currentState.runtimeType} → ${transition.nextState.runtimeType}',
      name: 'bloc',
    );
  }
}
