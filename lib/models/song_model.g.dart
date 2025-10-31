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
      genre: fields[7] as String?,
      trackNumber: fields[8] as int?,
      year: fields[9] as int?,
      composer: fields[10] as String?,
      playCount: fields[11] as int,
      lastPlayed: fields[12] as DateTime?,
      dateAdded: fields[13] as DateTime?,
      isFavorite: fields[14] as bool,
      mediaStoreId: fields[15] as int,
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
      ..write(obj.genre)
      ..writeByte(8)
      ..write(obj.trackNumber)
      ..writeByte(9)
      ..write(obj.year)
      ..writeByte(10)
      ..write(obj.composer)
      ..writeByte(11)
      ..write(obj.playCount)
      ..writeByte(12)
      ..write(obj.lastPlayed)
      ..writeByte(13)
      ..write(obj.dateAdded)
      ..writeByte(14)
      ..write(obj.isFavorite)
      ..writeByte(15)
      ..write(obj.mediaStoreId);
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
