import 'package:flutter/material.dart';
import 'package:waypoint/presentation/builder/builder_screen.dart' as builder;

class EditPlanScreen extends StatelessWidget {
  final String planId;
  const EditPlanScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    return builder.BuilderScreen(editPlanId: planId);
  }
}
