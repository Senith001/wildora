import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A development aid that constrains the app to mobile phone dimensions
/// when running on web, while allowing full-screen rendering on mobile devices.
///
/// This helps with UI testing and development by providing a consistent
/// mobile viewport in desktop browsers.
class MobilePreview extends StatelessWidget {
  const MobilePreview({super.key, required this.child});

  final Widget child;

  // iPhone-ish logical dimensions
  static const double _mobileWidth = 390.0;
  static const double _mobileHeight = 844.0;

  @override
  Widget build(BuildContext context) {
    // On web: constrain to mobile dimensions with background
    // On mobile: render full screen normally
    if (kIsWeb) {
      return ColoredBox(
        color: Colors.grey.shade300,
        child: Center(
          child: ClipRect(
            child: SizedBox(
              width: _mobileWidth,
              height: _mobileHeight,
              child: MediaQuery(
                // Override MediaQuery to report mobile dimensions to the app
                data: MediaQuery.of(context)
                    .copyWith(size: const Size(_mobileWidth, _mobileHeight)),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    // Native mobile: return child unchanged
    return child;
  }
}
