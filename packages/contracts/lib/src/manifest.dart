import 'json.dart';

class WorldPackageManifest {
  int formatVersion;
  String worldId;
  int version;
  String checksum;
  String license;
  String origin;
  String? sourceWorldId;
  bool aiGenerated;
  String author;
  int createdAt;

  WorldPackageManifest({
    required this.formatVersion,
    required this.worldId,
    required this.version,
    required this.checksum,
    required this.license,
    required this.origin,
    this.sourceWorldId,
    required this.aiGenerated,
    required this.author,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => {
        'formatVersion': formatVersion,
        'worldId': worldId,
        'version': version,
        'checksum': checksum,
        'license': license,
        'origin': origin,
        if (sourceWorldId != null) 'sourceWorldId': sourceWorldId,
        'aiGenerated': aiGenerated,
        'author': author,
        'createdAt': createdAt,
      };

  static WorldPackageManifest fromJson(Object? j) {
    final m = rawMap(j);
    return WorldPackageManifest(
      formatVersion: asIOr(m['formatVersion'], 1),
      worldId: asSOr(m['worldId'], ''),
      version: asIOr(m['version'], 1),
      checksum: asSOr(m['checksum'], ''),
      license: asSOr(m['license'], 'all-rights-reserved'),
      origin: asSOr(m['origin'], 'original'),
      sourceWorldId: asS(m['sourceWorldId']),
      aiGenerated: asBOr(m['aiGenerated'], true),
      author: asSOr(m['author'], ''),
      createdAt: asIOr(m['createdAt'], 0),
    );
  }
}

class RunPackageManifest {
  int formatVersion;
  String runId;
  String worldId;
  int worldVersion;
  String identityId;
  int turnNo;
  int chapter;
  String status;
  String? endingId;
  String checksum;
  bool aiGenerated;
  int createdAt;

  RunPackageManifest({
    required this.formatVersion,
    required this.runId,
    required this.worldId,
    required this.worldVersion,
    required this.identityId,
    required this.turnNo,
    required this.chapter,
    required this.status,
    this.endingId,
    required this.checksum,
    required this.aiGenerated,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => {
        'formatVersion': formatVersion,
        'runId': runId,
        'worldId': worldId,
        'worldVersion': worldVersion,
        'identityId': identityId,
        'turnNo': turnNo,
        'chapter': chapter,
        'status': status,
        if (endingId != null) 'endingId': endingId,
        'checksum': checksum,
        'aiGenerated': aiGenerated,
        'createdAt': createdAt,
      };

  static RunPackageManifest fromJson(Object? j) {
    final m = rawMap(j);
    return RunPackageManifest(
      formatVersion: asIOr(m['formatVersion'], 1),
      runId: asSOr(m['runId'], ''),
      worldId: asSOr(m['worldId'], ''),
      worldVersion: asIOr(m['worldVersion'], 1),
      identityId: asSOr(m['identityId'], ''),
      turnNo: asIOr(m['turnNo'], 0),
      chapter: asIOr(m['chapter'], 1),
      status: asSOr(m['status'], 'active'),
      endingId: asS(m['endingId']),
      checksum: asSOr(m['checksum'], ''),
      aiGenerated: asBOr(m['aiGenerated'], true),
      createdAt: asIOr(m['createdAt'], 0),
    );
  }
}
