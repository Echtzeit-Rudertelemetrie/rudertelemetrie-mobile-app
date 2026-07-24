double toSlider(int value, int min, int max) => (value - min) / (max - min);

int intFromSlider(double value, int min, int max) =>
    (value * (max - min) + min).round();
