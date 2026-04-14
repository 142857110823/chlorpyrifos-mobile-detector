// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detection_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DetectedPesticideAdapter extends TypeAdapter<DetectedPesticide> {
  @override
  final int typeId = 3;

  @override
  DetectedPesticide read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DetectedPesticide(
      name: fields[0] as String,
      type: fields[1] as PesticideType,
      concentration: fields[2] as double,
      maxResidueLimit: fields[3] as double,
      unit: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DetectedPesticide obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.concentration)
      ..writeByte(3)
      ..write(obj.maxResidueLimit)
      ..writeByte(4)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectedPesticideAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DetectionResultAdapter extends TypeAdapter<DetectionResult> {
  @override
  final int typeId = 4;

  @override
  DetectionResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DetectionResult(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      sampleName: fields[2] as String,
      sampleCategory: fields[3] as String?,
      riskLevel: fields[4] as RiskLevel,
      confidence: fields[5] as double,
      detectedPesticides: (fields[6] as List).cast<DetectedPesticide>(),
      spectralDataId: fields[7] as String?,
      notes: fields[8] as String?,
      imagePath: fields[9] as String?,
      isSynced: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DetectionResult obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.sampleName)
      ..writeByte(3)
      ..write(obj.sampleCategory)
      ..writeByte(4)
      ..write(obj.riskLevel)
      ..writeByte(5)
      ..write(obj.confidence)
      ..writeByte(6)
      ..write(obj.detectedPesticides)
      ..writeByte(7)
      ..write(obj.spectralDataId)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.imagePath)
      ..writeByte(10)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RiskLevelAdapter extends TypeAdapter<RiskLevel> {
  @override
  final int typeId = 1;

  @override
  RiskLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RiskLevel.safe;
      case 1:
        return RiskLevel.low;
      case 2:
        return RiskLevel.medium;
      case 3:
        return RiskLevel.high;
      case 4:
        return RiskLevel.critical;
      default:
        return RiskLevel.safe;
    }
  }

  @override
  void write(BinaryWriter writer, RiskLevel obj) {
    switch (obj) {
      case RiskLevel.safe:
        writer.writeByte(0);
        break;
      case RiskLevel.low:
        writer.writeByte(1);
        break;
      case RiskLevel.medium:
        writer.writeByte(2);
        break;
      case RiskLevel.high:
        writer.writeByte(3);
        break;
      case RiskLevel.critical:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiskLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PesticideTypeAdapter extends TypeAdapter<PesticideType> {
  @override
  final int typeId = 2;

  @override
  PesticideType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PesticideType.organophosphate;
      case 1:
        return PesticideType.carbamate;
      case 2:
        return PesticideType.pyrethroid;
      case 3:
        return PesticideType.neonicotinoid;
      case 4:
        return PesticideType.fungicide;
      case 5:
        return PesticideType.herbicide;
      case 6:
        return PesticideType.unknown;
      case 7:
        return PesticideType.phenylpyrazole;
      case 8:
        return PesticideType.organochlorine;
      case 9:
        return PesticideType.other;
      default:
        return PesticideType.organophosphate;
    }
  }

  @override
  void write(BinaryWriter writer, PesticideType obj) {
    switch (obj) {
      case PesticideType.organophosphate:
        writer.writeByte(0);
        break;
      case PesticideType.carbamate:
        writer.writeByte(1);
        break;
      case PesticideType.pyrethroid:
        writer.writeByte(2);
        break;
      case PesticideType.neonicotinoid:
        writer.writeByte(3);
        break;
      case PesticideType.fungicide:
        writer.writeByte(4);
        break;
      case PesticideType.herbicide:
        writer.writeByte(5);
        break;
      case PesticideType.unknown:
        writer.writeByte(6);
        break;
      case PesticideType.phenylpyrazole:
        writer.writeByte(7);
        break;
      case PesticideType.organochlorine:
        writer.writeByte(8);
        break;
      case PesticideType.other:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PesticideTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
