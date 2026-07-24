import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderPageMode { cover, simulation, slide, none }

enum ReaderPalette { white, eyeCare, parchment, coffee, night }

enum ReaderScript { simplified, traditional }

extension ReaderPageModeLabel on ReaderPageMode {
  String get label => switch (this) {
    ReaderPageMode.cover => '覆盖',
    ReaderPageMode.simulation => '仿真',
    ReaderPageMode.slide => '滑动',
    ReaderPageMode.none => '无',
  };
}

extension ReaderPaletteStyle on ReaderPalette {
  String get label => switch (this) {
    ReaderPalette.white => '白天',
    ReaderPalette.eyeCare => '护眼',
    ReaderPalette.parchment => '浅棕',
    ReaderPalette.coffee => '深棕',
    ReaderPalette.night => '夜间',
  };

  Color get background => switch (this) {
    ReaderPalette.white => const Color(0xFFFFFBF7),
    ReaderPalette.eyeCare => const Color(0xFFE4EDDE),
    ReaderPalette.parchment => const Color(0xFFF2E5D1),
    ReaderPalette.coffee => const Color(0xFF7A6B5B),
    ReaderPalette.night => const Color(0xFF24211F),
  };

  Color get foreground => switch (this) {
    ReaderPalette.coffee => const Color(0xFFF7EFE8),
    ReaderPalette.night => const Color(0xFFE8E2DC),
    _ => const Color(0xFF282421),
  };
}

class ReaderSettings {
  const ReaderSettings({
    this.brightness = .92,
    this.fontSize = 18,
    this.lineHeight = 1.8,
    this.letterSpacing = .2,
    this.paragraphSpacing = 16,
    this.horizontalPadding = 22,
    this.firstLineIndent = true,
    this.eyeCare = false,
    this.autoPage = false,
    this.landscape = false,
    this.pageMode = ReaderPageMode.cover,
    this.palette = ReaderPalette.white,
    this.script = ReaderScript.simplified,
  });

  final double brightness;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double horizontalPadding;
  final bool firstLineIndent;
  final bool eyeCare;
  final bool autoPage;
  final bool landscape;
  final ReaderPageMode pageMode;
  final ReaderPalette palette;
  final ReaderScript script;

  ReaderSettings copyWith({
    double? brightness,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    double? horizontalPadding,
    bool? firstLineIndent,
    bool? eyeCare,
    bool? autoPage,
    bool? landscape,
    ReaderPageMode? pageMode,
    ReaderPalette? palette,
    ReaderScript? script,
  }) => ReaderSettings(
    brightness: brightness ?? this.brightness,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    horizontalPadding: horizontalPadding ?? this.horizontalPadding,
    firstLineIndent: firstLineIndent ?? this.firstLineIndent,
    eyeCare: eyeCare ?? this.eyeCare,
    autoPage: autoPage ?? this.autoPage,
    landscape: landscape ?? this.landscape,
    pageMode: pageMode ?? this.pageMode,
    palette: palette ?? this.palette,
    script: script ?? this.script,
  );
}

class ReaderSettingsStore {
  static const _prefix = 'reader.';

  Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReaderSettings(
      brightness: prefs.getDouble('${_prefix}brightness') ?? .92,
      fontSize: prefs.getDouble('${_prefix}fontSize') ?? 18,
      lineHeight: prefs.getDouble('${_prefix}lineHeight') ?? 1.8,
      letterSpacing: prefs.getDouble('${_prefix}letterSpacing') ?? .2,
      paragraphSpacing: prefs.getDouble('${_prefix}paragraphSpacing') ?? 16,
      horizontalPadding: prefs.getDouble('${_prefix}horizontalPadding') ?? 22,
      firstLineIndent: prefs.getBool('${_prefix}firstLineIndent') ?? true,
      eyeCare: prefs.getBool('${_prefix}eyeCare') ?? false,
      autoPage: prefs.getBool('${_prefix}autoPage') ?? false,
      landscape: prefs.getBool('${_prefix}landscape') ?? false,
      pageMode:
          ReaderPageMode.values[(prefs.getInt('${_prefix}pageMode') ?? 0)
              .clamp(0, ReaderPageMode.values.length - 1)
              .toInt()],
      palette:
          ReaderPalette.values[(prefs.getInt('${_prefix}palette') ?? 0)
              .clamp(0, ReaderPalette.values.length - 1)
              .toInt()],
      script:
          ReaderScript.values[(prefs.getInt('${_prefix}script') ?? 0)
              .clamp(0, ReaderScript.values.length - 1)
              .toInt()],
    );
  }

  Future<void> save(ReaderSettings value) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble('${_prefix}brightness', value.brightness),
      prefs.setDouble('${_prefix}fontSize', value.fontSize),
      prefs.setDouble('${_prefix}lineHeight', value.lineHeight),
      prefs.setDouble('${_prefix}letterSpacing', value.letterSpacing),
      prefs.setDouble('${_prefix}paragraphSpacing', value.paragraphSpacing),
      prefs.setDouble('${_prefix}horizontalPadding', value.horizontalPadding),
      prefs.setBool('${_prefix}firstLineIndent', value.firstLineIndent),
      prefs.setBool('${_prefix}eyeCare', value.eyeCare),
      prefs.setBool('${_prefix}autoPage', value.autoPage),
      prefs.setBool('${_prefix}landscape', value.landscape),
      prefs.setInt('${_prefix}pageMode', value.pageMode.index),
      prefs.setInt('${_prefix}palette', value.palette.index),
      prefs.setInt('${_prefix}script', value.script.index),
    ]);
  }
}
