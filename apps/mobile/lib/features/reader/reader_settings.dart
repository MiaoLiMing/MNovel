import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderPageMode { cover, vertical, simulation, none }

enum ReaderPalette { parchment, eyeCare, blossom, white, night }

extension ReaderPageModeLabel on ReaderPageMode {
  String get label => switch (this) {
    ReaderPageMode.cover => '覆盖',
    ReaderPageMode.vertical => '上下',
    ReaderPageMode.simulation => '仿真',
    ReaderPageMode.none => '无',
  };
}

extension ReaderPaletteStyle on ReaderPalette {
  String get label => switch (this) {
    ReaderPalette.parchment => '纸黄',
    ReaderPalette.eyeCare => '护眼',
    ReaderPalette.blossom => '樱粉',
    ReaderPalette.white => '纯白',
    ReaderPalette.night => '夜间',
  };

  Color get background => switch (this) {
    ReaderPalette.parchment => const Color(0xFFF8F0D6),
    ReaderPalette.eyeCare => const Color(0xFFDCEBD8),
    ReaderPalette.blossom => const Color(0xFFF8E8E8),
    ReaderPalette.white => const Color(0xFFFAFAF7),
    ReaderPalette.night => const Color(0xFF171916),
  };

  Color get foreground => this == ReaderPalette.night
      ? const Color(0xFFD8DBD5)
      : const Color(0xFF2B2B27);
}

class ReaderSettings {
  const ReaderSettings({
    this.brightness = .86,
    this.fontSize = 20,
    this.lineHeight = 1.9,
    this.letterSpacing = .35,
    this.paragraphSpacing = 18,
    this.horizontalPadding = 24,
    this.firstLineIndent = true,
    this.eyeCare = false,
    this.autoPage = false,
    this.landscape = false,
    this.pageMode = ReaderPageMode.cover,
    this.palette = ReaderPalette.parchment,
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
  );
}

class ReaderSettingsStore {
  static const _prefix = 'reader.';

  Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReaderSettings(
      brightness: prefs.getDouble('${_prefix}brightness') ?? .86,
      fontSize: prefs.getDouble('${_prefix}fontSize') ?? 20,
      lineHeight: prefs.getDouble('${_prefix}lineHeight') ?? 1.9,
      letterSpacing: prefs.getDouble('${_prefix}letterSpacing') ?? .35,
      paragraphSpacing: prefs.getDouble('${_prefix}paragraphSpacing') ?? 18,
      horizontalPadding: prefs.getDouble('${_prefix}horizontalPadding') ?? 24,
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
    ]);
  }
}
