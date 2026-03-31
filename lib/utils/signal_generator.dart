import 'dart:math';

double generateSine(int frequency, double elapsedSeconds) =>
    sin(2 * pi * frequency * elapsedSeconds);
