// lib/models/member.dart
class Member {
  final String id;
  final String name;
  final String phone;
  final bool active;

  const Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.active,
  });

  Member copyWith({String? id, String? name, String? phone, bool? active}) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      active: active ?? this.active,
    );
  }
}