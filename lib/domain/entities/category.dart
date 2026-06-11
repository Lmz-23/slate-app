import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.createdAt,
  });

  Category copyWith({
    String? id,
    String? name,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, colorHex, createdAt];
}