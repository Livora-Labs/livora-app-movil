import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Barra indicadora de progreso y pasos para el Wizard de recolección (Hogar).
class CreateRequestStepperHeader extends StatelessWidget {
  const CreateRequestStepperHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (index) {
              final isDone = index < currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDone || isCurrent
                              ? LivoraColors.forest
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < totalSteps - 1) const SizedBox(width: 6),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paso ${currentStep + 1} de $totalSteps',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                stepTitles[currentStep],
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: LivoraColors.deep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
