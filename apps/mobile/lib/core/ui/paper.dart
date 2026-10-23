import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 纸面卡片：细边框 + 微阴影，圆角 12，不用渐变与发光
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.background,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? background;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? paperCardColor(theme.brightness),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? theme.dividerColor),
        boxShadow: shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.28 : 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content);
  }
}

/// 风险 / 稀有度的小圆点
class PaperDot extends StatelessWidget {
  const PaperDot({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 细边框小徽章（版本、来源、状态等）
class PaperBadge extends StatelessWidget {
  const PaperBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
  });

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1.4,
          color: textColor ?? c,
          fontFamilyFallback: kSerifFontFallback,
        ),
      ),
    );
  }
}

/// 区块小标题
class PaperSectionLabel extends StatelessWidget {
  const PaperSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: theme.colorScheme.secondary,
        fontFamilyFallback: kSerifFontFallback,
      ),
    );
  }
}

/// 统一的输入框外观
InputDecoration paperInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
  Widget? suffixIcon,
  bool dense = false,
}) {
  final theme = Theme.of(context);
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: theme.dividerColor),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: paperCardColor(theme.brightness),
    isDense: dense,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: outline,
    border: outline,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.colorScheme.primary),
    ),
  );
}
