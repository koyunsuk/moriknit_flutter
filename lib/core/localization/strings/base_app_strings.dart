import '../app_strings.dart';

abstract class BaseAppStrings extends AppStrings {
  const BaseAppStrings();

  @override
  String needleSize(double size) {
    if (size <= 0) return needleNotSet;
    return size % 1 == 0 ? '${size.toInt()}mm' : '${size}mm';
  }
}
