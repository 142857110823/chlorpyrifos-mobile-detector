// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spectral_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpectralDataAdapter extends TypeAdapter<SpectralData> {
  @override
  final int typeId = 0;

  @override
  SpectralData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpectralData(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      wavelengths: (fields[2] as List).cast<double>(),
      intensities: (fields[3] as List).cast<double>(),
      deviceId: fields[4] as String,
      metadata: (fields[5] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, SpectralData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.wavelengths)
      ..writeByte(3)
      ..write(obj.intensities)
      ..writeByte(4)
      ..write(obj.deviceId)
      ..writeByte(5)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpectralDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
