/// Value object representing this application installation.
///
/// The [id] is a UUID v4 generated at first launch and persisted. The
/// [name] is optional and reserved for future display purposes.
class Device {
  final String id;
  final String? name;

  const Device({required this.id, this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device && other.id == id && other.name == name);

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Device(id: $id, name: $name)';
}
