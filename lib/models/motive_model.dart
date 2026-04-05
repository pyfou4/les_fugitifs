class MotiveModel {
  final String id;
  final String name;
  final String preparations;
  final String delays;
  final String violence;
  final String image;

  MotiveModel({
    required this.id,
    required this.name,
    required this.preparations,
    required this.delays,
    required this.violence,
    required this.image,
  });

  factory MotiveModel.fromJson(Map<String, dynamic> json) {
    return MotiveModel(
      id: json['id'] as String,
      name: json['name'] as String,
      preparations: json['preparations'] as String,
      delays: json['delays'] as String,
      violence: json['violence'] as String,
      image: json['image'] as String,
    );
  }

  factory MotiveModel.fromRuntime(Map<String, dynamic> json) {
    return MotiveModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      preparations: (json['preparations'] ?? '').toString(),
      delays: (json['delays'] ?? '').toString(),
      violence: (json['violence'] ?? '').toString(),
      image: (json['imagePath'] ?? json['image'] ?? '').toString(),
    );
  }
}
