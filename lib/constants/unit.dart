/// Physical unit of a measurement. [name] stays the persistence key; [label] is
/// the only form that may be shown to the user.
enum Unit {
  mN('mN'),
  N('N'),
  m('m'),
  km('km'),
  ms('ms'),
  s('s'),
  min('min'),
  deg('°'),
  mps('m/s'),
  kmh('km/h'),
  mps2('m/s²'),
  spm('spm'),
  count(''),
  ratio(''),
  W('W'),
  J('J'),
  radps('rad/s'),
  pct('%'),

  /// Seconds per 500 m. Displayed as `m:ss`, never as a decimal.
  pace('/500m');

  final String label;
  const Unit(this.label);
}
