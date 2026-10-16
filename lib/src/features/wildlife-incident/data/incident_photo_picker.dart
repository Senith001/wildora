import 'package:image_picker/image_picker.dart';
import 'incident_report.dart';

abstract interface class IncidentPhotoPicker {
  Future<IncidentPhoto?> pick(ImageSource source);
}

class DeviceIncidentPhotoPicker implements IncidentPhotoPicker {
  DeviceIncidentPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  @override
  Future<IncidentPhoto?> pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return image == null ? null : readIncidentPhoto(image);
  }
}

Future<IncidentPhoto> readIncidentPhoto(XFile image) async {
  final bytes = await image.readAsBytes();
  if (bytes.isEmpty || bytes.length > maxIncidentPhotoBytes) {
    throw const FormatException('Choose an image smaller than 5 MB.');
  }
  // Detect image content rather than trusting a filename or browser MIME type.
  String? contentType;
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    contentType = 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
    contentType = 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    contentType = 'image/webp';
  }
  if (contentType == null) {
    throw const FormatException('Choose a JPEG, PNG or WebP image.');
  }
  return IncidentPhoto(bytes: bytes, contentType: contentType);
}
