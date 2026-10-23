import 'package:contracts/contracts.dart';
import 'package:flutter/material.dart';

/// 纸质视觉调色板（docs/UI与交互.md §6）
/// 浅色：暖白纸面 + 墨色文字 + 朱红点缀；夜读：暖黑底 + 暖黄字。
abstract final class PaperColors {
  // 浅色（纸面）
  static const lightBg = Color(0xFFF5EFE2);
  static const lightCard = Color(0xFFFBF7EE);
  static const lightInk = Color(0xFF2A2622);
  static const lightSub = Color(0xFF6B635A);
  static const lightDivider = Color(0xFFDED5C4);
  static const lightAccent = Color(0xFFA63D2F);

  // 夜读（暖黑）
  static const nightBg = Color(0xFF1C1710);
  static const nightCard = Color(0xFF272016);
  static const nightInk = Color(0xFFE8E0D2);
  static const nightSub = Color(0xFFA2957F);
  static const nightDivider = Color(0xFF3B3226);
  static const nightAccent = Color(0xFFC4573F);
}

/// 衬线中文字体 fallback（宋体优先，正文用）
const List<String> kSerifFontFallback = <String>[
  'Songti SC',
  'STSong',
  'Noto Serif CJK SC',
  'Source Han Serif SC',
  'SimSun',
  'serif',
];

ThemeData buildLightTheme() => _buildTheme(
      brightness: Brightness.light,
      bg: PaperColors.lightBg,
      card: PaperColors.lightCard,
      ink: PaperColors.lightInk,
      sub: PaperColors.lightSub,
      divider: PaperColors.lightDivider,
      accent: PaperColors.lightAccent,
    );

ThemeData buildNightTheme() => _buildTheme(
      brightness: Brightness.dark,
      bg: PaperColors.nightBg,
      card: PaperColors.nightCard,
      ink: PaperColors.nightInk,
      sub: PaperColors.nightSub,
      divider: PaperColors.nightDivider,
      accent: PaperColors.nightAccent,
    );

ThemeData _buildTheme({
  required Brightness brightness,
  required Color bg,
  required Color card,
  required Color ink,
  required Color sub,
  required Color divider,
  required Color accent,
}) {
  final rawText = brightness == Brightness.light
      ? Typography.material2014().black
      : Typography.material2014().white;
  final text = rawText.apply(
    fontFamilyFallback: kSerifFontFallback,
    bodyColor: ink,
    displayColor: ink,
  );
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    secondary: sub,
    onSecondary: bg,
    surface: bg,
    onSurface: ink,
    error: accent,
    onError: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    dividerColor: divider,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      titleTextStyle: text.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    iconTheme: IconThemeData(color: sub),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// 卡片面颜色（跟随明暗）
Color paperCardColor(Brightness brightness) =>
      brightness == Brightness.dark ? PaperColors.nightCard : PaperColors.lightCard;

/// 身份卡稀有度配色：common 灰 / rare 青 / unique 金
Color rarityColor(Rarity rarity, {required bool night}) => switch (rarity) {
      Rarity.common => night ? const Color(0xFF8A8071) : const Color(0xFF8A8378),
      Rarity.rare => night ? const Color(0xFF63B0A6) : const Color(0xFF2F6F6A),
      Rarity.unique => night ? const Color(0xFFD4AF37) : const Color(0xFFA8842C),
    };

/// 选项风险点配色：低 / 中 / 高（中性灰阶到朱红）
Color riskColor(Risk risk, {required bool night}) => switch (risk) {
      Risk.low => night ? const Color(0xFF7D7466) : const Color(0xFF9A9188),
      Risk.medium => night ? const Color(0xFFB08D5B) : const Color(0xFF8F7440),
      Risk.high => night ? const Color(0xFFC4573F) : const Color(0xFFA63D2F),
    };
