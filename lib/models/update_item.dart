class UpdateItem {
  final String id;
  final String title;
  final String? description;
  final String? imagePath; // local image path (optional)
  final DateTime createdAt;

  const UpdateItem({
    required this.id,
    required this.title,
    this.description,
    this.imagePath,
    required this.createdAt,
  });

  UpdateItem copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    DateTime? createdAt,
  }) {
    return UpdateItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}