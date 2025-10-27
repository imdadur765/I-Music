// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MusicPlaybackStateAdapter extends TypeAdapter<MusicPlaybackState> {
  @override
  final int typeId = 4;

  @override
  MusicPlaybackState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MusicPlaybackState(
      currentSong: fields[0] as Song?,
      position: fields[1] as Duration,
      duration: fields[2] as Duration,
      isPlaying: fields[3] as bool,
      isShuffling: fields[4] as bool,
      repeatMode: fields[5] as int,
      currentQueue: (fields[6] as List).cast<Song>(),
    );
  }

  @override
  void write(BinaryWriter writer, MusicPlaybackState obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.currentSong)
      ..writeByte(1)
      ..write(obj.position)
      ..writeByte(2)
      ..write(obj.duration)
      ..writeByte(3)
      ..write(obj.isPlaying)
      ..writeByte(4)
      ..write(obj.isShuffling)
      ..writeByte(5)
      ..write(obj.repeatMode)
      ..writeByte(6)
      ..write(obj.currentQueue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicPlaybackStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
