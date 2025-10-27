// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Song(
      id: fields[0] as String,
      uri: fields[1] as String,
      title: fields[2] as String,
      artist: fields[3] as String,
      album: fields[4] as String?,
      duration: fields[5] as int,
      albumArt: fields[6] as String?,
      albumId: fields[7] as int,
      genre: fields[8] as String?,
      trackNumber: fields[9] as int?,
      year: fields[10] as int?,
      composer: fields[11] as String?,
      playCount: fields[12] as int,
      lastPlayed: fields[13] as DateTime?,
      dateAdded: fields[14] as DateTime?,
      isFavorite: fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.uri)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.artist)
      ..writeByte(4)
      ..write(obj.album)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.albumArt)
      ..writeByte(7)
      ..write(obj.albumId)
      ..writeByte(8)
      ..write(obj.genre)
      ..writeByte(9)
      ..write(obj.trackNumber)
      ..writeByte(10)
      ..write(obj.year)
      ..writeByte(11)
      ..write(obj.composer)
      ..writeByte(12)
      ..write(obj.playCount)
      ..writeByte(13)
      ..write(obj.lastPlayed)
      ..writeByte(14)
      ..write(obj.dateAdded)
      ..writeByte(15)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
