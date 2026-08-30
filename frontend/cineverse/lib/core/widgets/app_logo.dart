import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('lib/app/assets/Icon.svg', height: height);
  }
}
