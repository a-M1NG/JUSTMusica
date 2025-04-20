class SettingsModel {
  final String key;
  final String value;

  SettingsModel({
    required this.key,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      key: map['key'],
      value: map['value'],
    );
  }
}