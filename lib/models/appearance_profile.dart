/// Holds all user-selected appearance attributes used to generate
/// an AI fashion-model prompt (no personal photo required).
class AppearanceProfile {
  // ── Identity ──────────────────────────────────────────────────────
  AgeGroup ageGroup;
  GenderPresentation gender;

  // ── Body ──────────────────────────────────────────────────────────
  BodyShape bodyShape;
  ModelHeight height;
  SkinTone skinTone;

  // ── Hair ──────────────────────────────────────────────────────────
  HairLength hairLength;
  HairStyle hairStyle;
  HairColor hairColor;

  // ── Pose & Expression ─────────────────────────────────────────────
  ModelPose pose;
  FacialExpression expression;

  // ── Accessories ───────────────────────────────────────────────────
  Set<ModelAccessory> accessories;

  AppearanceProfile({
    this.ageGroup = AgeGroup.adult,
    this.gender = GenderPresentation.feminine,
    this.bodyShape = BodyShape.regular,
    this.height = ModelHeight.average,
    this.skinTone = SkinTone.medium,
    this.hairLength = HairLength.medium,
    this.hairStyle = HairStyle.straight,
    this.hairColor = HairColor.black,
    this.pose = ModelPose.standingFront,
    this.expression = FacialExpression.neutral,
    Set<ModelAccessory>? accessories,
  }) : accessories = accessories ?? {};

  /// Builds a descriptive English prompt fragment for the AI model.
  String toPromptString() {
    final accText = accessories.isEmpty
        ? 'no accessories'
        : accessories.map((a) => a.label).join(', ');

    return 'A ${ageGroup.label} ${gender.label} fashion model '
        'with a ${bodyShape.label} body shape, ${height.label} height, '
        '${skinTone.label} skin tone, ${hairLength.label} ${hairStyle.label} '
        '${hairColor.label} hair. '
        'The model is ${pose.label} with a ${expression.label} expression. '
        'The model is wearing $accText as pre-existing accessories.';
  }
}

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AgeGroup {
  child('Child'),
  teen('Teen'),
  youngAdult('Young Adult'),
  adult('Adult'),
  senior('Senior');

  const AgeGroup(this.label);
  final String label;
}

enum GenderPresentation {
  feminine('Feminine'),
  masculine('Masculine'),
  neutral('Neutral');

  const GenderPresentation(this.label);
  final String label;
}

enum BodyShape {
  slim('Slim'),
  regular('Regular'),
  athletic('Athletic'),
  curvy('Curvy'),
  plusSize('Plus Size');

  const BodyShape(this.label);
  final String label;
}

enum ModelHeight {
  short('Short'),
  average('Average'),
  tall('Tall');

  const ModelHeight(this.label);
  final String label;
}

enum SkinTone {
  fair('Fair'),
  light('Light'),
  medium('Medium'),
  tan('Tan'),
  brown('Brown'),
  deep('Deep');

  const SkinTone(this.label);
  final String label;
}

enum HairLength {
  bald('Bald'),
  short('Short'),
  medium('Medium'),
  long('Long');

  const HairLength(this.label);
  final String label;
}

enum HairStyle {
  straight('Straight'),
  wavy('Wavy'),
  curly('Curly'),
  coiled('Coiled'),
  updo('Updo');

  const HairStyle(this.label);
  final String label;
}

enum HairColor {
  black('Black'),
  brown('Brown'),
  blonde('Blonde'),
  red('Red'),
  gray('Gray'),
  white('White'),
  colorful('Colorful');

  const HairColor(this.label);
  final String label;
}

enum ModelPose {
  standingFront('standing facing the camera'),
  fortyFive('standing at a 45-degree angle'),
  sideView('standing in side view'),
  walking('walking naturally');

  const ModelPose(this.label);
  final String label;

  String get displayName {
    switch (this) {
      case ModelPose.standingFront:
        return 'Front';
      case ModelPose.fortyFive:
        return '45°';
      case ModelPose.sideView:
        return 'Side';
      case ModelPose.walking:
        return 'Walking';
    }
  }
}

enum FacialExpression {
  neutral('neutral'),
  smile('smiling');

  const FacialExpression(this.label);
  final String label;
}

enum ModelAccessory {
  glasses('Glasses'),
  hijab('Hijab'),
  hat('Hat'),
  scarf('Scarf'),
  jewelry('Jewelry'),
  watch('Watch'),
  bag('Bag'),
  belt('Belt');

  const ModelAccessory(this.label);
  final String label;
}
