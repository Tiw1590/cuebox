/// 工程类型：Cue 列表工程 或 Pad 工程（二者独立）。
enum ShowKind { cue, cart }

/// 控制 Cue 的动作：播放 / 暂停 / 停止（控制它前面的目标音频）。
enum ControlAction { play, pause, stop }

/// Cue 列表里的一条 cue：存储音频文件引用 + 播放参数。
class Cue {
  Cue({
    required this.id,
    required this.name,
    required this.uri,
    this.note = '',
    this.startMs = 0,
    this.endMs = 0,
    this.preWaitMs = 0,
    this.postWaitMs = 0,
    this.autoNext = false,
    this.playNextTogether = false,
    this.followGlobal = true,
    this.controlAction,
    this.controlTargetCueId,
    this.loop = false,
    this.volume = 1.0,
    this.fadeInMs = 20,
    this.fadeOutMs = 150,
  });

  final String id;
  String name;
  final String uri;
  String note;

  /// 播放起点（毫秒），0 表示文件开头。
  int startMs;

  /// 播放终点（毫秒），0 表示文件结尾。
  int endMs;

  /// 开始前等待（毫秒）。
  int preWaitMs;

  /// 结束后等待（毫秒）。
  int postWaitMs;

  /// 播完自动接下一个。
  bool autoNext;

  /// 触发时同时播放下一个。
  bool playNextTogether;

  /// 跟随全局（项目默认）参数；关闭后以本音频自己的参数为准。
  bool followGlobal;

  /// 控制 Cue：非 null 表示这是一条控制项。
  ControlAction? controlAction;

  /// 控制 Cue 的目标音频 id。
  String? controlTargetCueId;
  bool loop;
  double volume;
  int fadeInMs;
  int fadeOutMs;

  Duration get fadeIn => Duration(milliseconds: fadeInMs);
  Duration get fadeOut => Duration(milliseconds: fadeOutMs);

  Cue copyWith({
    String? name,
    String? note,
    int? startMs,
    int? endMs,
    int? preWaitMs,
    int? postWaitMs,
    bool? autoNext,
    bool? playNextTogether,
    bool? followGlobal,
    ControlAction? controlAction,
    String? controlTargetCueId,
    bool? loop,
    double? volume,
    int? fadeInMs,
    int? fadeOutMs,
  }) {
    return Cue(
      id: id,
      name: name ?? this.name,
      uri: uri,
      note: note ?? this.note,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      preWaitMs: preWaitMs ?? this.preWaitMs,
      postWaitMs: postWaitMs ?? this.postWaitMs,
      autoNext: autoNext ?? this.autoNext,
      playNextTogether: playNextTogether ?? this.playNextTogether,
      followGlobal: followGlobal ?? this.followGlobal,
      controlAction: controlAction ?? this.controlAction,
      controlTargetCueId: controlTargetCueId ?? this.controlTargetCueId,
      loop: loop ?? this.loop,
      volume: volume ?? this.volume,
      fadeInMs: fadeInMs ?? this.fadeInMs,
      fadeOutMs: fadeOutMs ?? this.fadeOutMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'uri': uri,
    'note': note,
    'startMs': startMs,
    'endMs': endMs,
    'preWaitMs': preWaitMs,
    'postWaitMs': postWaitMs,
    'autoNext': autoNext,
    'playNextTogether': playNextTogether,
    'followGlobal': followGlobal,
    'controlAction': controlAction?.name,
    'controlTargetCueId': controlTargetCueId,
    'loop': loop,
    'volume': volume,
    'fadeInMs': fadeInMs,
    'fadeOutMs': fadeOutMs,
  };

  factory Cue.fromJson(Map<String, dynamic> json) {
    return Cue(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      note: json['note'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      preWaitMs: (json['preWaitMs'] as num?)?.toInt() ?? 0,
      postWaitMs: (json['postWaitMs'] as num?)?.toInt() ?? 0,
      autoNext: json['autoNext'] as bool? ?? false,
      playNextTogether: json['playNextTogether'] as bool? ?? false,
      followGlobal: json['followGlobal'] as bool? ?? true,
      controlAction: ControlAction.values
          .asNameMap()[json['controlAction'] as String?],
      controlTargetCueId: json['controlTargetCueId'] as String?,
      loop: json['loop'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      fadeInMs: (json['fadeInMs'] as num?)?.toInt() ?? 20,
      fadeOutMs: (json['fadeOutMs'] as num?)?.toInt() ?? 150,
    );
  }
}

/// Pad 里的一个格子：音频引用 + 触发方式（solo/叠放）。
class CartSlot {
  CartSlot({
    required this.id,
    required this.name,
    required this.uri,
    this.note = '',
    this.startMs = 0,
    this.endMs = 0,
    this.shortcutKeyId,
    this.shortcutLabel,
    this.followGlobal = true,
    this.solo = true,
    this.loop = false,
    this.volume = 1.0,
    this.fadeInMs = 20,
    this.fadeOutMs = 150,
  });

  final String id;
  String name;
  final String uri;
  String note;

  /// 播放起点（毫秒），0 表示文件开头。
  int startMs;

  /// 播放终点（毫秒），0 表示文件结尾。
  int endMs;

  /// 快捷键（LogicalKeyboardKey.keyId），null 表示未设置。
  int? shortcutKeyId;

  /// 快捷键显示名称（如 A / 5 / F1）。
  String? shortcutLabel;

  /// 跟随全局（项目默认）参数；关闭后以本 Card 自己的参数为准。
  bool followGlobal;
  bool solo;
  bool loop;
  double volume;
  int fadeInMs;
  int fadeOutMs;

  Duration get fadeIn => Duration(milliseconds: fadeInMs);
  Duration get fadeOut => Duration(milliseconds: fadeOutMs);

  CartSlot copyWith({
    String? name,
    String? note,
    int? startMs,
    int? endMs,
    int? shortcutKeyId,
    String? shortcutLabel,
    bool? followGlobal,
    bool? solo,
    bool? loop,
    double? volume,
    int? fadeInMs,
    int? fadeOutMs,
  }) {
    return CartSlot(
      id: id,
      name: name ?? this.name,
      uri: uri,
      note: note ?? this.note,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      shortcutKeyId: shortcutKeyId ?? this.shortcutKeyId,
      shortcutLabel: shortcutLabel ?? this.shortcutLabel,
      followGlobal: followGlobal ?? this.followGlobal,
      solo: solo ?? this.solo,
      loop: loop ?? this.loop,
      volume: volume ?? this.volume,
      fadeInMs: fadeInMs ?? this.fadeInMs,
      fadeOutMs: fadeOutMs ?? this.fadeOutMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'uri': uri,
    'note': note,
    'startMs': startMs,
    'endMs': endMs,
    'shortcutKeyId': shortcutKeyId,
    'shortcutLabel': shortcutLabel,
    'followGlobal': followGlobal,
    'solo': solo,
    'loop': loop,
    'volume': volume,
    'fadeInMs': fadeInMs,
    'fadeOutMs': fadeOutMs,
  };

  factory CartSlot.fromJson(Map<String, dynamic> json) {
    return CartSlot(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      note: json['note'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      shortcutKeyId: (json['shortcutKeyId'] as num?)?.toInt(),
      shortcutLabel: json['shortcutLabel'] as String?,
      followGlobal: json['followGlobal'] as bool? ?? true,
      solo: json['solo'] as bool? ?? true,
      loop: json['loop'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      fadeInMs: (json['fadeInMs'] as num?)?.toInt() ?? 20,
      fadeOutMs: (json['fadeOutMs'] as num?)?.toInt() ?? 150,
    );
  }
}

/// 整场演出数据：Cue 列表 + Pad（两种视图共享）。
class Show {
  Show({
    String? id,
    this.name = '我的演出',
    this.kind = ShowKind.cue,
    List<Cue>? cues,
    List<CartSlot>? cartSlots,
    this.locked = false,
    this.defaultVolume = 1.0,
    this.defaultFadeInMs = 20,
    this.defaultFadeOutMs = 150,
    this.defaultLoop = false,
  }) : id = (id == null || id.isEmpty)
           ? 'show_${DateTime.now().microsecondsSinceEpoch}'
           : id,
       cues = cues ?? [],
       cartSlots = cartSlots ?? [];

  final String id;
  final String name;
  final ShowKind kind;
  final List<Cue> cues;
  final List<CartSlot> cartSlots;

  /// 演出锁定：隐藏编辑与误操作入口，仅保留播放操作。
  final bool locked;

  /// 工程默认播放参数（新加入的音频使用）。
  final double defaultVolume;
  final int defaultFadeInMs;
  final int defaultFadeOutMs;
  final bool defaultLoop;

  Show copyWith({
    String? name,
    ShowKind? kind,
    List<Cue>? cues,
    List<CartSlot>? cartSlots,
    bool? locked,
    double? defaultVolume,
    int? defaultFadeInMs,
    int? defaultFadeOutMs,
    bool? defaultLoop,
  }) {
    return Show(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      cues: cues ?? this.cues,
      cartSlots: cartSlots ?? this.cartSlots,
      locked: locked ?? this.locked,
      defaultVolume: defaultVolume ?? this.defaultVolume,
      defaultFadeInMs: defaultFadeInMs ?? this.defaultFadeInMs,
      defaultFadeOutMs: defaultFadeOutMs ?? this.defaultFadeOutMs,
      defaultLoop: defaultLoop ?? this.defaultLoop,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'locked': locked,
    'defaultVolume': defaultVolume,
    'defaultFadeInMs': defaultFadeInMs,
    'defaultFadeOutMs': defaultFadeOutMs,
    'defaultLoop': defaultLoop,
    'cues': cues.map((c) => c.toJson()).toList(),
    'cartSlots': cartSlots.map((c) => c.toJson()).toList(),
  };

  factory Show.fromJson(Map<String, dynamic> json) {
    return Show(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '我的演出',
      kind:
          ShowKind.values.asNameMap()[json['kind'] as String?] ??
          ((json['cues'] as List<dynamic>? ?? []).isNotEmpty
              ? ShowKind.cue
              : (json['cartSlots'] as List<dynamic>? ?? []).isNotEmpty
              ? ShowKind.cart
              : ShowKind.cue),
      locked: json['locked'] as bool? ?? false,
      defaultVolume: (json['defaultVolume'] as num?)?.toDouble() ?? 1.0,
      defaultFadeInMs: (json['defaultFadeInMs'] as num?)?.toInt() ?? 20,
      defaultFadeOutMs: (json['defaultFadeOutMs'] as num?)?.toInt() ?? 150,
      defaultLoop: json['defaultLoop'] as bool? ?? false,
      cues: (json['cues'] as List<dynamic>? ?? [])
          .map((e) => Cue.fromJson(e as Map<String, dynamic>))
          .toList(),
      cartSlots: (json['cartSlots'] as List<dynamic>? ?? [])
          .map((e) => CartSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 演出库：多个演出 + 当前激活的演出 id。
class ShowLibrary {
  ShowLibrary({required this.shows, required this.activeShowId});

  final List<Show> shows;
  final String activeShowId;

  Show get activeShow =>
      shows.firstWhere((s) => s.id == activeShowId, orElse: () => shows.first);

  Map<String, dynamic> toJson() => {
    'shows': shows.map((s) => s.toJson()).toList(),
    'activeShowId': activeShowId,
  };

  factory ShowLibrary.fromJson(Map<String, dynamic> json) {
    final rawShows = json['shows'];
    if (rawShows is List) {
      final shows = rawShows
          .map((e) => Show.fromJson(e as Map<String, dynamic>))
          .toList();
      if (shows.isEmpty) {
        final fallback = Show();
        return ShowLibrary(shows: [fallback], activeShowId: fallback.id);
      }
      var activeId = json['activeShowId'] as String? ?? '';
      if (!shows.any((s) => s.id == activeId)) {
        activeId = shows.first.id;
      }
      return ShowLibrary(shows: shows, activeShowId: activeId);
    }
    // 兼容旧版本数据：单场演出直接包裹。
    final legacy = Show.fromJson(json);
    if (legacy.cues.isNotEmpty && legacy.cartSlots.isNotEmpty) {
      // 旧数据里 Cue 和 Cart 混在同一场，拆成两个独立工程。
      final cueShow = Show(
        id: '${legacy.id}_cue',
        name: legacy.name,
        kind: ShowKind.cue,
        cues: legacy.cues,
        locked: legacy.locked,
      );
      final cartShow = Show(
        id: '${legacy.id}_cart',
        name: '${legacy.name} · Card',
        kind: ShowKind.cart,
        cartSlots: legacy.cartSlots,
        locked: legacy.locked,
      );
      return ShowLibrary(shows: [cueShow, cartShow], activeShowId: cueShow.id);
    }
    return ShowLibrary(shows: [legacy], activeShowId: legacy.id);
  }
}
