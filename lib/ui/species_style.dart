import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';

Color speciesColor(Species species) {
  return switch (species) {
    Species.pig => const Color(0xFFCF2A2A),
    Species.cattle => const Color(0xFF8C4A07),
    Species.goat => const Color(0xFF007A33),
    Species.sheep => const Color(0xFF00B4E6),
    Species.poultry => const Color(0xFFCF8724),
  };
}
