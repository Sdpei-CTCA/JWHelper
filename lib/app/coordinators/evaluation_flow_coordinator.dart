import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:JWHelper/core/constants/config.dart';

typedef OpenHelperFn = Future<void> Function();
typedef ResetEvaluationStateFn = void Function();

class EvaluationFlowCoordinator {
  static bool shouldShowDialog({
    required bool evaluationRequired,
    required bool dialogShowing,
  }) {
    return evaluationRequired && !dialogShowing;
  }

  static Future<void> openWebEvaluation(BuildContext context) async {
    final Uri url = Uri.parse(Config.evaluationUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法打开网页')));
      }
    }
  }

  static Future<void> openHelperAndReset({
    required OpenHelperFn openHelper,
    required ResetEvaluationStateFn resetEvaluationState,
  }) async {
    await openHelper();
    resetEvaluationState();
  }
}
