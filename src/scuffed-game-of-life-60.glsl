precision mediump float;
precision mediump int;

const float CELL_SIZE = 32.0;  // pixels per cell
const float STEP_TIME = 0.3;   // seconds per generation
const int MAX_STEPS = 5;

const int GRID_WIDTH  = int(1920.0 / CELL_SIZE); // 60
const int GRID_HEIGHT = int(1080.0 / CELL_SIZE); // 33

// Simple hash for float->float [0,1]
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Wrap coordinate within grid bounds (assumes positive)
ivec2 wrapCoord(ivec2 c) {
    int x = c.x;
    int y = c.y;
    if (x < 0) x += GRID_WIDTH;
    else if (x >= GRID_WIDTH) x -= GRID_WIDTH;
    if (y < 0) y += GRID_HEIGHT;
    else if (y >= GRID_HEIGHT) y -= GRID_HEIGHT;
    return ivec2(x, y);
}

// Compute cell state seed for given cell + cycle number (deterministic)
float cellSeed(ivec2 cell, int cycle) {
    // Mix cell coords and cycle to get a reproducible pseudo-random seed
    return hash21(vec2(cell) * 0.73 + float(cycle) * 0.37);
}

// Compute alive state (1.0 = alive, 0.0 = dead) for a single cell and cycle
float cellAlive(ivec2 cell, int cycle) {
    float seed = cellSeed(cell, cycle);

    // Forcing cursor positions alive
    ivec2 emacsCell = ivec2(int(emacs_cursor.x / CELL_SIZE), int(emacs_cursor.y / CELL_SIZE));
    ivec2 mouseCell = ivec2(int(mouse_cursor.x / CELL_SIZE), int(mouse_cursor.y / CELL_SIZE));
    if (all(equal(cell, emacsCell)) || all(equal(cell, mouseCell))) {
        return 1.0;
    }
    return (seed > 0.82) ? 1.0 : 0.0;
}

void main() {
    ivec2 pixel = ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y));

    // Skip ~60% pixels in a checkerboard + random pattern for speed
    bool skipPixel = false;
    // Checkerboard pattern
    if ((pixel.x / int(CELL_SIZE) + pixel.y / int(CELL_SIZE)) % 2 == 0) {
        // In checker squares, randomly skip 70%
        if (hash21(vec2(pixel) * 0.1) < 0.7) skipPixel = true;
    } else {
        // In other squares, skip 50%
        if (hash21(vec2(pixel) * 0.15 + 5.0) < 0.5) skipPixel = true;
    }
    if (skipPixel) {
        // Just output black early, skip simulation
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Identify which cell this pixel belongs to
    ivec2 cell = ivec2(pixel.x / int(CELL_SIZE), pixel.y / int(CELL_SIZE));

    // Calculate simulation step and cycle offset per cell
    int cycleCount = MAX_STEPS;
    float t = time / STEP_TIME;
    int globalStep = int(floor(t));
    float offsetSeed = hash21(vec2(cell) * 0.97);
    int cycleOffset = int(floor(offsetSeed * float(MAX_STEPS)));
    int stepWithOffset = (globalStep + cycleOffset) % MAX_STEPS;
    int cycle = (globalStep + cycleOffset) / MAX_STEPS;

    // Simulate Game of Life up to stepWithOffset
    // We'll simulate only for the current cell, neighbors are sampled from initial seed states

    // Current state starts from initial seed (cycle)
    float state = cellAlive(cell, cycle);

    // Helper to get neighbor state for cycle
    float neighborAlive(ivec2 c) {
        c = wrapCoord(c);
        return cellAlive(c, cycle);
    }

    for (int step = 0; step < MAX_STEPS; step++) {
        if (step >= stepWithOffset) break;

        int neighbors = 0;
        for (int oy = -1; oy <= 1; oy++) {
            for (int ox = -1; ox <= 1; ox++) {
                if (ox == 0 && oy == 0) continue;
                if (neighborAlive(cell + ivec2(ox, oy)) > 0.5) neighbors++;
            }
        }

        if (state > 0.5) {
            state = (neighbors == 2 || neighbors == 3) ? 1.0 : 0.0;
        } else {
            state = (neighbors == 3) ? 1.0 : 0.0;
        }
    }

    // Color alive cells green, dead cells black
    vec3 color = state > 0.5 ? vec3(0.0, 1.0, 0.0) : vec3(0.0);

    gl_FragColor = vec4(color, 1.0);
}