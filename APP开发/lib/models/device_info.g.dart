// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceInfoAdapter extends TypeAdapter<DeviceInfo> {
  @override
  final int typeId = 6;

  @override
  DeviceInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceInfo(
      id: fields[0] as String,
      name: fields[1] as String,
      macAddress: fields[2] as String?,
      firmwareVersion: fields[3] as String?,
      batteryLevel: fields[4] as int?,
      lastConnectedAt: fields[5] as DateTime?,
      isFavorite: fields[6] as bool,
      capabilities: (fields[7] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, DeviceInfo obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.macAddress)
      ..writeByte(3)
      ..write(obj.firmwareVersion)
      ..writeByte(4)
      ..write(obj.batteryLevel)
      ..writeByte(5)
      ..write(obj.lastConnectedAt)
      ..writeByte(6)
      ..write(obj.isFavorite)
      ..writeByte(7)
      ..write(obj.capabilities);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DeviceConnectionStateAdapter extends TypeAdapter<DeviceConnectionState> {
  @override
  final int typeId = 5;

  @override
  DeviceConnectionState read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DeviceConnectionState.disconnected;
      case 1:
        return DeviceConnectionState.connecting;
      case 2:
        return DeviceConnectionState.connected;
      case 3:
        return DeviceConnectionState.error;
      default:
        return DeviceConnectionState.disconnected;
    }
  }

  @override
  void write(BinaryWriter writer, DeviceConnectionState obj) {
    switch (obj) {
      case DeviceConnectionState.disconnected:
        writer.writeByte(0);
        break;
      case DeviceConnectionState.connecting:
        writer.writeByte(1);
        break;
      case DeviceConnectionState.connected:
        writer.writeByte(2);
        break;
      case DeviceConnectionState.error:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceConnectionStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
