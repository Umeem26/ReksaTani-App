import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'MONGO_URI', obfuscate: true)
  static final String mongoUri = _Env.mongoUri;

  @EnviedField(varName: 'CLOUDINARY_CLOUD_NAME', obfuscate: true)
  static final String cloudinaryCloudName = _Env.cloudinaryCloudName;

  @EnviedField(varName: 'CLOUDINARY_UPLOAD_PRESET', obfuscate: true)
  static final String cloudinaryUploadPreset = _Env.cloudinaryUploadPreset;
}
