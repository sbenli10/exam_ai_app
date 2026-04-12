class AvatarConfig {
  const AvatarConfig({
    required this.stylePack,
    required this.skinTone,
    required this.hairStyle,
    required this.hairColor,
    required this.eyes,
    required this.brows,
    required this.mouth,
    required this.accessory,
    required this.outfit,
    required this.bg,
  });

  final String stylePack;
  final int skinTone;
  final int hairStyle;
  final int hairColor;
  final int eyes;
  final int brows;
  final int mouth;
  final int accessory;
  final int outfit;
  final int bg;

  factory AvatarConfig.defaults() => const AvatarConfig(
    stylePack: 'classic',
    skinTone: 2,
    hairStyle: 1,
    hairColor: 2,
    eyes: 1,
    brows: 1,
    mouth: 1,
    accessory: 0,
    outfit: 1,
    bg: 1,
  );

  AvatarConfig copyWith({
    String? stylePack,
    int? skinTone,
    int? hairStyle,
    int? hairColor,
    int? eyes,
    int? brows,
    int? mouth,
    int? accessory,
    int? outfit,
    int? bg,
  }) {
    return AvatarConfig(
      stylePack: stylePack ?? this.stylePack,
      skinTone: skinTone ?? this.skinTone,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyes: eyes ?? this.eyes,
      brows: brows ?? this.brows,
      mouth: mouth ?? this.mouth,
      accessory: accessory ?? this.accessory,
      outfit: outfit ?? this.outfit,
      bg: bg ?? this.bg,
    );
  }

  Map<String, dynamic> toJson(String userId) => {
    'user_id': userId,
    'style_pack': stylePack,
    'skin_tone': skinTone,
    'hair_style': hairStyle,
    'hair_color': hairColor,
    'eyes': eyes,
    'brows': brows,
    'mouth': mouth,
    'accessory': accessory,
    'outfit': outfit,
    'bg': bg,
  };

  static AvatarConfig fromJson(Map<String, dynamic> json) => AvatarConfig(
    stylePack: (json['style_pack'] as String?) ?? 'classic',
    skinTone: (json['skin_tone'] as num?)?.toInt() ?? 2,
    hairStyle: (json['hair_style'] as num?)?.toInt() ?? 1,
    hairColor: (json['hair_color'] as num?)?.toInt() ?? 2,
    eyes: (json['eyes'] as num?)?.toInt() ?? 1,
    brows: (json['brows'] as num?)?.toInt() ?? 1,
    mouth: (json['mouth'] as num?)?.toInt() ?? 1,
    accessory: (json['accessory'] as num?)?.toInt() ?? 0,
    outfit: (json['outfit'] as num?)?.toInt() ?? 1,
    bg: (json['bg'] as num?)?.toInt() ?? 1,
  );
}