class AstroData {
  final int batteryLevel;
  final Map<String, String> trafficLights;
  final Map<String, String> trafficComments;
  final String powerHour;
  final String totemEmoji;
  final String totemName;
  final String motto;
  final String mission;

  AstroData({
    required this.batteryLevel,
    required this.trafficLights,
    required this.trafficComments,
    required this.powerHour,
    required this.totemEmoji,
    required this.totemName,
    required this.motto,
    required this.mission,
  });

  factory AstroData.fromJson(Map<String, dynamic> json) {
    return AstroData(
      batteryLevel: json['battery_level'] ?? 50,
      trafficLights: Map<String, String>.from(json['traffic_lights'] ?? {}),
      trafficComments: Map<String, String>.from(json['traffic_comments'] ?? {}),
      powerHour: json['power_hour'] ?? "",
      totemEmoji: json['totem_emoji'] ?? "✨",
      totemName: json['totem_name'] ?? "",
      motto: json['motto'] ?? "",
      mission: json['mission'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'battery_level': batteryLevel,
      'traffic_lights': trafficLights,
      'traffic_comments': trafficComments,
      'power_hour': powerHour,
      'totem_emoji': totemEmoji,
      'totem_name': totemName,
      'motto': motto,
      'mission': mission,
    };
  }
}
