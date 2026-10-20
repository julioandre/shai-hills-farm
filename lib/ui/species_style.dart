import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';

Color speciesColor(Species species) {
  return switch (species) {
    Species.pig => const Color(0xFFC46B4A),
    Species.cattle => const Color(0xFF6B4F3A),
    Species.goat => const Color(0xFF5E7A3A),
    Species.poultry => const Color(0xFFB5893A),
  };
}
