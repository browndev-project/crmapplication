import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget whatsAppIcon({double size = 20, Color? color}) {
  return SvgPicture.asset(
    'assets/whatapp-ui/whatsapp.svg',
    width: size,
    height: size,
    colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
  );
}
