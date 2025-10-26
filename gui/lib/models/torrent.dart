/// Transmission torrent model
class Torrent {
  final int id;
  final String name;
  final double percentDone;  // 0.0 to 1.0
  final int totalSize;
  final int downloadedEver;
  final int rateDownload;
  final int rateUpload;
  final int eta;
  final String status;
  final List<String> files;

  Torrent({
    required this.id,
    required this.name,
    required this.percentDone,
    required this.totalSize,
    required this.downloadedEver,
    required this.rateDownload,
    required this.rateUpload,
    required this.eta,
    required this.status,
    required this.files,
  });

  factory Torrent.fromJson(Map<String, dynamic> json) {
    // Get status string from status code
    String getStatusString(int statusCode) {
      switch (statusCode) {
        case 0:
          return 'stopped';
        case 1:
          return 'check_wait';
        case 2:
          return 'check';
        case 3:
          return 'download_wait';
        case 4:
          return 'download';
        case 5:
          return 'seed_wait';
        case 6:
          return 'seed';
        default:
          return 'unknown';
      }
    }

    return Torrent(
      id: json['id'] as int,
      name: json['name'] as String,
      percentDone: (json['percentDone'] as num).toDouble(),  // Handle both int and double
      totalSize: json['totalSize'] as int,
      downloadedEver: json['downloadedEver'] as int,
      rateDownload: json['rateDownload'] as int,
      rateUpload: json['rateUpload'] as int,
      eta: json['eta'] as int,
      status: getStatusString(json['status'] as int),
      files: (json['files'] as List?)
              ?.map((f) => f['name'] as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'percentDone': percentDone,
      'totalSize': totalSize,
      'downloadedEver': downloadedEver,
      'rateDownload': rateDownload,
      'rateUpload': rateUpload,
      'eta': eta,
      'status': status,
      'files': files,
    };
  }
}
