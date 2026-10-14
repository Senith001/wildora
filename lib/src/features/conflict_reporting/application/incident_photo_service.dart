import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class IncidentPhoto {
  const IncidentPhoto(this.name, this.bytes, this.contentType);
  final String name;
  final Uint8List bytes;
  final String contentType;
}

abstract interface class IncidentPhotoService {
  Future<IncidentPhoto?> select(ImageSource source);
}

/// The actual byte format determines metadata; filenames are not trusted.
class DeviceIncidentPhotoService implements IncidentPhotoService {
  DeviceIncidentPhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  static IncidentPhoto validate(String name, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 5 MB.');
    }
    final type = _contentType(bytes);
    if (type == null) {
      throw const FormatException('Choose a JPEG, PNG or WebP photo.');
    }
    return IncidentPhoto(name, Uint8List.fromList(bytes), type);
  }

  static String? _contentType(Uint8List bytes) {
    bool startsWith(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => bytes[i] == signature[i],
        ).every((matches) => matches);
    if (startsWith([0xff, 0xd8, 0xff])) {
      return 'image/jpeg';
    }
    if (startsWith([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10])) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  @override
  Future<IncidentPhoto?> select(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    return image == null
        ? null
        : validate(image.name, await image.readAsBytes());
  }
}
