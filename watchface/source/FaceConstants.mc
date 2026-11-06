module FaceStyle {
    const BALANCED = 0;
    const DATA_FOCUS = 1;
    const MINIMAL = 2;
}

module FaceTheme {
    const NEON_PURPLE = 0;
    const DEEP_PURPLE = 1;
    const MIDNIGHT_BLUE = 2;
    const GRAPHITE = 3;
    const PURE_BLACK = 4;
    const GREEN = 5;
    const BLUE = 6;
    const RED = 7;
}

module FacePalettePreset {
    const CUSTOM = 0;
    const GREEN = 1;
    const BROWN = 2;
    const PURPLE = 3;
}

module FaceWeatherGlyph {
    const SUN = 0;
    const PARTLY_CLOUDY = 1;
    const CLOUD = 2;
    const RAIN = 3;
    const SNOW = 4;
}

module FaceSlot {
    const TOP_LEFT = 1;
    // Keep native editor identifiers compatible with the original slots:
    // id 2 was RIGHT and id 3 was CENTER.
    const TOP_RIGHT = 2;
    const BOTTOM_LEFT = 3;
    const BOTTOM_RIGHT = 4;
}
