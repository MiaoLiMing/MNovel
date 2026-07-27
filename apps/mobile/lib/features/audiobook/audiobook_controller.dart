import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/content_repository.dart';
import '../../domain/content.dart';

enum AudiobookPlaybackState { idle, loading, playing, paused, completed, error }

List<String> splitTtsSegments(String text, {int maxLength = 120}) {
  final remainingParts = <String>[];
  var remaining = text.trim();
  const breakCharacters = '。！？；.!?;\n';
  while (remaining.length > maxLength) {
    final minimum = (maxLength * .55).floor();
    var end = 0;
    for (var index = maxLength; index >= minimum; index--) {
      if (breakCharacters.contains(remaining[index - 1])) {
        end = index;
        break;
      }
    }
    if (end == 0) end = maxLength;
    remainingParts.add(remaining.substring(0, end).trim());
    remaining = remaining.substring(end).trim();
  }
  if (remaining.isNotEmpty) remainingParts.add(remaining);
  return remainingParts.where((value) => value.isNotEmpty).toList();
}

class AudiobookController extends ChangeNotifier {
  AudiobookController._();

  static final instance = AudiobookController._();

  final FlutterTts _tts = FlutterTts();
  ContentRepository? _repository;
  ContentItem? item;
  Chapter? chapter;
  int chapterIndex = 0;
  int paragraphIndex = 0;
  double rate = .5;
  double pitch = 1;
  double volume = 1;
  String? voiceName;
  List<Map<String, dynamic>> voices = const [];
  AudiobookPlaybackState state = AudiobookPlaybackState.idle;
  String? errorMessage;
  DateTime? sleepEndsAt;
  bool stopAtChapterEnd = false;
  Timer? _sleepTimer;
  Timer? _initializationTimer;
  void Function()? _cancelInitializationWait;
  int _generation = 0;
  bool _initialized = false;

  bool get isPlaying => state == AudiobookPlaybackState.playing;
  bool get isPaused => state == AudiobookPlaybackState.paused;
  bool get canGoPrevious => chapterIndex > 0 || paragraphIndex > 0;
  bool get canGoNext => item != null && chapterIndex < item!.episodeCount - 1;
  String get currentParagraph {
    final value = chapter;
    if (value == null || value.paragraphs.isEmpty) return '';
    return value.paragraphs[paragraphIndex.clamp(
      0,
      value.paragraphs.length - 1,
    )];
  }

  double get chapterProgress {
    final count = chapter?.paragraphs.length ?? 0;
    if (count <= 1) return 0;
    return (paragraphIndex / (count - 1)).clamp(0, 1);
  }

  Future<void> open({
    required ContentItem item,
    required int initialChapterIndex,
    required ContentRepository repository,
    bool autoplay = false,
  }) async {
    await _initialize();
    _repository = repository;
    final changedBook = this.item?.id != item.id;
    this.item = item;
    if (changedBook || chapter == null) {
      chapterIndex = initialChapterIndex.clamp(0, item.episodeCount - 1);
      paragraphIndex = 0;
      await _loadChapter(chapterIndex);
    }
    notifyListeners();
    if (autoplay) await play();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    rate = prefs.getDouble('audiobook.rate') ?? .5;
    pitch = prefs.getDouble('audiobook.pitch') ?? 1;
    volume = prefs.getDouble('audiobook.volume') ?? 1;
    voiceName = prefs.getString('audiobook.voice');
    try {
      await _awaitInitialization(_tts.awaitSpeakCompletion(true));
      await _awaitInitialization(_tts.setLanguage('zh-CN'));
      await _awaitInitialization(_applySettings());
      final rawVoices = await _awaitInitialization(_tts.getVoices);
      voices = (rawVoices as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((voice) => Map<String, dynamic>.from(voice))
          .where((voice) {
            final locale = voice['locale']?.toString().toLowerCase() ?? '';
            return locale.startsWith('zh');
          })
          .toList(growable: false);
    } catch (_) {
      _initialized = false;
      voices = const [];
    }
  }

  Future<T> _awaitInitialization<T>(Future<T> operation) {
    final completer = Completer<T>();
    final timer = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('系统语音服务初始化超时'));
      }
    });
    _initializationTimer = timer;
    _cancelInitializationWait = () {
      if (!completer.isCompleted) {
        completer.completeError(StateError('听书页面已关闭'));
      }
    };
    operation.then(
      (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future.whenComplete(() {
      timer.cancel();
      if (identical(_initializationTimer, timer)) {
        _initializationTimer = null;
        _cancelInitializationWait = null;
      }
    });
  }

  void cancelPendingInitialization() {
    _initializationTimer?.cancel();
    _cancelInitializationWait?.call();
    _initializationTimer = null;
    _cancelInitializationWait = null;
  }

  Future<void> _loadChapter(int index) async {
    final repository = _repository;
    final content = item;
    if (repository == null || content == null) return;
    state = AudiobookPlaybackState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      chapter = await repository.chapter(content, index);
      final totalCount = chapter?.totalCount;
      if (totalCount != null && totalCount > 0) {
        item = content.copyWith(episodeCount: totalCount);
      }
      chapterIndex = index;
      paragraphIndex = 0;
      state = AudiobookPlaybackState.paused;
    } catch (error) {
      state = AudiobookPlaybackState.error;
      errorMessage = '章节加载失败，请检查网络或切换书源：$error';
    }
    notifyListeners();
  }

  Future<void> play() async {
    if (chapter == null) await _loadChapter(chapterIndex);
    final value = chapter;
    if (value == null || value.paragraphs.isEmpty) return;
    final generation = ++_generation;
    state = AudiobookPlaybackState.playing;
    errorMessage = null;
    notifyListeners();
    try {
      await _applySettings().timeout(const Duration(seconds: 5));
      while (generation == _generation &&
          state == AudiobookPlaybackState.playing) {
        final active = chapter;
        if (active == null || active.paragraphs.isEmpty) break;
        final text = active
            .paragraphs[paragraphIndex.clamp(0, active.paragraphs.length - 1)];
        for (final segment in splitTtsSegments(text)) {
          final result = await _tts
              .speak(segment, focus: true)
              .timeout(const Duration(seconds: 60));
          if (generation != _generation ||
              state != AudiobookPlaybackState.playing) {
            return;
          }
          if (result != 1) throw StateError('系统语音服务未能开始播放');
        }
        if (paragraphIndex < active.paragraphs.length - 1) {
          paragraphIndex++;
          notifyListeners();
          continue;
        }
        if (stopAtChapterEnd || !canGoNext) {
          state = AudiobookPlaybackState.completed;
          stopAtChapterEnd = false;
          notifyListeners();
          return;
        }
        await _loadChapter(chapterIndex + 1);
        if (state == AudiobookPlaybackState.error) return;
        state = AudiobookPlaybackState.playing;
        notifyListeners();
      }
    } catch (error) {
      if (generation != _generation) return;
      try {
        await _tts.stop().timeout(const Duration(seconds: 5));
      } catch (_) {}
      state = AudiobookPlaybackState.error;
      errorMessage = '系统朗读失败。请确认设备已安装中文语音：$error';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    _generation++;
    try {
      await _tts.pause().timeout(const Duration(seconds: 5));
    } catch (_) {
      try {
        await _tts.stop().timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    state = AudiobookPlaybackState.paused;
    notifyListeners();
  }

  Future<void> stop() async {
    _generation++;
    try {
      await _tts.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
    state = AudiobookPlaybackState.idle;
    notifyListeners();
  }

  Future<void> previousChapter() async {
    final resume = isPlaying;
    _generation++;
    try {
      await _tts.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
    if (paragraphIndex > 0) {
      paragraphIndex = 0;
      state = AudiobookPlaybackState.paused;
      notifyListeners();
      return;
    }
    if (chapterIndex > 0) {
      await _loadChapter(chapterIndex - 1);
      if (resume && state != AudiobookPlaybackState.error) await play();
    }
  }

  Future<void> nextChapter() async {
    if (!canGoNext) return;
    final resume = isPlaying;
    _generation++;
    try {
      await _tts.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _loadChapter(chapterIndex + 1);
    if (resume && state != AudiobookPlaybackState.error) await play();
  }

  Future<void> seekParagraph(double value) async {
    final count = chapter?.paragraphs.length ?? 0;
    if (count == 0) return;
    final resume = isPlaying;
    _generation++;
    try {
      await _tts.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
    paragraphIndex = (value.clamp(0, 1) * (count - 1)).round();
    state = AudiobookPlaybackState.paused;
    notifyListeners();
    if (resume) await play();
  }

  Future<void> skipParagraph(int delta) async {
    final count = chapter?.paragraphs.length ?? 0;
    if (count == 0) return;
    final target = (paragraphIndex + delta).clamp(0, count - 1);
    await seekParagraph(count <= 1 ? 0 : target / (count - 1));
  }

  Future<void> updateVoice({
    double? rate,
    double? pitch,
    double? volume,
    String? voiceName,
    String? locale,
  }) async {
    if (rate != null) this.rate = rate.clamp(.2, .9);
    if (pitch != null) this.pitch = pitch.clamp(.5, 2);
    if (volume != null) this.volume = volume.clamp(0, 1);
    if (voiceName != null) this.voiceName = voiceName;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble('audiobook.rate', this.rate),
      prefs.setDouble('audiobook.pitch', this.pitch),
      prefs.setDouble('audiobook.volume', this.volume),
      if (this.voiceName != null)
        prefs.setString('audiobook.voice', this.voiceName!),
    ]);
    await _applySettings(locale: locale);
    notifyListeners();
  }

  Future<void> _applySettings({String? locale}) async {
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    if (voiceName != null) {
      await _tts.setVoice({'name': voiceName!, 'locale': locale ?? 'zh-CN'});
    }
  }

  void setSleepTimer(Duration? duration, {bool chapterEnd = false}) {
    _sleepTimer?.cancel();
    stopAtChapterEnd = chapterEnd;
    if (duration == null) {
      sleepEndsAt = null;
    } else {
      sleepEndsAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        sleepEndsAt = null;
        unawaited(pause());
      });
    }
    notifyListeners();
  }
}
