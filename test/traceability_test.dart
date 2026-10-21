import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/traceability.dart';

Animal _animal({
  required String tag,
  OriginType origin = OriginType.born,
  AnimalStatus status = AnimalStatus.onFarm,
  String? motherTag,
  String? fatherTag,
  double? birthWeightKg,
  String? sourceFarm,
  String? supplierName,
  double? purchaseWeightKg,
  double? purchasePrice,
  double? transportCost,
  double? saleWeightKg,
  double? salePrice,
}) {
  final today = DateTime(2026, 3, 4);
  return Animal(
    id: tag,
    tag: tag,
    species: Species.pig,
    sex: Sex.female,
    status: status,
    updatedAt: today,
    origin: origin,
    breed: 'Large White',
    locationId: 'piggery',
    motherTag: motherTag,
    fatherTag: fatherTag,
    dateOfBirth: today,
    birthWeightKg: birthWeightKg,
    birthLocationId: 'piggery',
    sourceFarm: sourceFarm,
    supplierName: supplierName,
    purchaseDate: today,
    purchaseWeightKg: purchaseWeightKg,
    purchasePrice: purchasePrice,
    transportCost: transportCost,
    saleDate: today,
    saleWeightKg: saleWeightKg,
    salePrice: salePrice,
    buyerName: 'Kojo',
    buyerContact: '0244000001',
  );
}

void main() {
  test('a born animal needs parents already on the register', () {
    final mother = _animal(tag: 'SOW-1');
    final calf = _animal(
      tag: 'PIG-1',
      motherTag: 'SOW-1',
      fatherTag: 'BOAR-9',
      birthWeightKg: 1.4,
    );
    expect(
      traceProblem(calf, [mother]),
      'Father BOAR-9 is not on the register.',
    );
    expect(
      traceProblem(calf, [
        mother,
        _animal(tag: 'BOAR-9', status: AnimalStatus.onFarm),
      ]),
      isNull,
    );
  });

  test('a purchase records price per kg and a profit estimate', () {
    final bought = _animal(
      tag: 'PIG-2',
      origin: OriginType.purchased,
      status: AnimalStatus.sold,
      sourceFarm: 'Shai mill',
      supplierName: 'Ama',
      purchaseWeightKg: 20,
      purchasePrice: 400,
      transportCost: 50,
      saleWeightKg: 80,
      salePrice: 1200,
    );
    expect(traceProblem(bought, const []), isNull);
    expect(pricePerKg(bought.salePrice, bought.saleWeightKg), 15);
    expect(profitEstimate(bought), 750);
  });

  test('dressing percentage is carcass over live weight', () {
    expect(dressingPercent(60, 80), 75);
    expect(dressingPercent(90, 80), greaterThan(100));
  });
}
