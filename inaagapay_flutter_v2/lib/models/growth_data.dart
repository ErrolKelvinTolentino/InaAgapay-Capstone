// lib/models/growth_data.dart
class WeightData {
  final int week;
  final double l;
  final double m;
  final double s;
  final double sd3neg;
  final double sd2neg;
  final double sd1neg;
  final double sd0;
  final double sd1;
  final double sd2;
  final double sd3;

  WeightData({
    required this.week,
    required this.l,
    required this.m,
    required this.s,
    required this.sd3neg,
    required this.sd2neg,
    required this.sd1neg,
    required this.sd0,
    required this.sd1,
    required this.sd2,
    required this.sd3,
  });

  factory WeightData.fromMap(Map<String, dynamic> map) {
    return WeightData(
      week: map['week'] as int,
      l: map['l'] as double,
      m: map['m'] as double,
      s: map['s'] as double,
      sd3neg: map['sd3neg'] as double,
      sd2neg: map['sd2neg'] as double,
      sd1neg: map['sd1neg'] as double,
      sd0: map['sd0'] as double,
      sd1: map['sd1'] as double,
      sd2: map['sd2'] as double,
      sd3: map['sd3'] as double,
    );
  }
}

class HeightData {
  final int week;
  final double l;
  final double m;
  final double s;
  final double sd;
  final double sd3neg;
  final double sd2neg;
  final double sd1neg;
  final double sd0;
  final double sd1;
  final double sd2;
  final double sd3;

  HeightData({
    required this.week,
    required this.l,
    required this.m,
    required this.s,
    required this.sd,
    required this.sd3neg,
    required this.sd2neg,
    required this.sd1neg,
    required this.sd0,
    required this.sd1,
    required this.sd2,
    required this.sd3,
  });

  factory HeightData.fromMap(Map<String, dynamic> map) {
    return HeightData(
      week: map['week'] as int,
      l: map['l'] as double,
      m: map['m'] as double,
      s: map['s'] as double,
      sd: map['sd'] as double,
      sd3neg: map['sd3neg'] as double,
      sd2neg: map['sd2neg'] as double,
      sd1neg: map['sd1neg'] as double,
      sd0: map['sd0'] as double,
      sd1: map['sd1'] as double,
      sd2: map['sd2'] as double,
      sd3: map['sd3'] as double,
    );
  }
}

class GrowthAssessment {
  final double value;
  final int week;
  final String gender;
  final String parameter;
  final double zScore;
  final String classification;

  GrowthAssessment({
    required this.value,
    required this.week,
    required this.gender,
    required this.parameter,
    required this.zScore,
    required this.classification,
  });
}