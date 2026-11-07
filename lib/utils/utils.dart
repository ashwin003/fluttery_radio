double valueFromPercentageInRange({required double min, max, percentage}) {
  return percentage * (max - min) + min;
}

double percentageFromValueInRange({required double min, max, value}) {
  return (value - min) / (max - min);
}
