import 'package:flutter/services.dart';

import 'progress_service.dart';

/// Short vibrations (only when "Vibration" is on in Settings).
class Haptics {
  Haptics(this._progress);
  final ProgressService _progress;

  void light() {
    if (_progress.vibration) HapticFeedback.selectionClick();
  }

  void medium() {
    if (_progress.vibration) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (_progress.vibration) HapticFeedback.heavyImpact();
  }
}
