import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/trainer_scenario.dart';

/// 評価に対応する色とアイコン。
///
/// 色だけで意味を伝えないよう、必ずアイコンとラベルを添えて使う。
({Color color, IconData icon}) verdictStyle(TrainerVerdict verdict) =>
    switch (verdict) {
      TrainerVerdict.best => (
        color: AppColors.accent,
        icon: Icons.check_circle_rounded,
      ),
      TrainerVerdict.reasonable => (
        color: AppColors.warning,
        icon: Icons.adjust_rounded,
      ),
      TrainerVerdict.mistake => (
        color: AppColors.danger,
        icon: Icons.error_rounded,
      ),
    };
