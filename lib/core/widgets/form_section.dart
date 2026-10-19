import 'package:flutter/material.dart';

import '../theme.dart';

class FormSection extends StatelessWidget {
  const FormSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md - 4),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class FieldIcon extends StatelessWidget {
  const FieldIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.iconBackground,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}
