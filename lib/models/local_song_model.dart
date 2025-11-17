class LocalSong {
  final String id;
  final String title;
  final String album;
  final String artist;
  final String path;
  final int duration;
  final int size;
  final String albumId;
  final String uri;

  LocalSong({
    required this.id,
    required this.title,
    required this.album,
    required this.artist,
    required this.path,
    required this.duration,
    required this.size,
    this.albumId = '',
    this.uri = '',
  });

  String get formattedDuration {
    final minutes = (duration / 1000) ~/ 60;
    final seconds = ((duration / 1000) % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}