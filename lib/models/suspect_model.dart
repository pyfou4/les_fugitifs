class SuspectModel {
  final String id;
  final String name;
  final int age;
  final String profession;
  final String build;
  final String image;

  SuspectModel({
    required this.id,
    required this.name,
    required this.age,
    required this.profession,
    required this.build,
    required this.image,
  });

  factory SuspectModel.fromJson(Map<String, dynamic> json) {
    return SuspectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      profession: json['profession'] as String,
      build: json['build'] as String,
      image: json['image'] as String,
    );
  }

  factory SuspectModel.fromRuntime(Map<String, dynamic> json) {
    return SuspectModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      age: _readInt(json['age']),
      profession: (json['profession'] ?? '').toString(),
      build: (json['build'] ?? '').toString(),
      image: (json['imagePath'] ?? json['image'] ?? '').toString(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
