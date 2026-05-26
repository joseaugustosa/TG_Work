import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Kanban activo em todas as plataformas.
bool get firestoreWorkloadReduceOnDesktop => false;

/// Relógio de trabalho manual desligado no Windows Desktop (usa IDE session tracking no PC).
bool get disableManualWorkTimerOnDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
