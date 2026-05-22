/// Snapshot of a single cast member persisted on the download manifest
/// so the detail modal can render the cast section offline without any
/// catalog access.
///
/// Lives in the domain layer because the `DownloadRepository` contract
/// surfaces it on its caching call. Its JSON shape mirrors the manifest
/// sidecar format owned by `DownloadManifestEntry` in infrastructure.
class CachedCastMember {
  final String name;
  final String? role;
  final String? photoUrl;

  const CachedCastMember({required this.name, this.role, this.photoUrl});

  Map<String, dynamic> toJson() => {
    'name': name,
    if (role != null) 'role': role,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };

  static CachedCastMember? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    return CachedCastMember(
      name: name,
      role: json['role'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCastMember &&
          other.name == name &&
          other.role == role &&
          other.photoUrl == photoUrl);

  @override
  int get hashCode => Object.hash(name, role, photoUrl);
}
