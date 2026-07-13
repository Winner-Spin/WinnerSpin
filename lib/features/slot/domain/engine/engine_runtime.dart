import 'dart:math';

const int kEngineColumns = 6;
const int kEngineRows = 5;
const int kEngineTotalSlots = kEngineColumns * kEngineRows;

Random engineRng = Random();

void resetEngineRngForTesting(int seed) {
  engineRng = Random(seed);
}
