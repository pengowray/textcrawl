// Conway's Game of Life - Local Simulation, cursor seeding
// Works without persistent buffers by computing each cell's state
// from initial seed and evolving locally up to N steps.

const float CELL_SIZE = 16.0; // pixels per cell
const float STEP_TIME = 0.2; // seconds per generation
const int   MAX_STEPS = 7;   // number of generations simulated per pixel

// Hash helpers
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// HSV→RGB
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0., 1./3., 2./3.)) * 6. - 3.);
    return c.z * mix(vec3(1.), clamp(p - 1., 0., 1.), c.y);
}

// Index helper for local array
const int S = 2*MAX_STEPS+1;
int idx(int x, int y) { return (y+MAX_STEPS)*S + (x+MAX_STEPS); }

vec4 shade(vec2 cs) {
    // Map pixel → grid coords
    vec2 pixel = cs * resolution;
    ivec2 cell = ivec2(floor(pixel / CELL_SIZE));
    ivec2 gridSize = ivec2(floor(resolution / CELL_SIZE));

    // Generation index
    int gen = int(floor(time / STEP_TIME));

    // Build initial neighborhood
    float stateA[S*S];
    float stateB[S*S];

    for (int oy=-MAX_STEPS; oy<=MAX_STEPS; oy++) {
        for (int ox=-MAX_STEPS; ox<=MAX_STEPS; ox++) {
            ivec2 cpos = cell + ivec2(ox, oy);

            // Wrap around edges
            cpos = (cpos + gridSize) % gridSize;

            // Base seed
            float seed = hash21(vec2(cpos) / vec2(gridSize) + float(gen / MAX_STEPS) * 0.123);

            // Spawn live cell under cursor
            vec2 ec = floor(emacs_cursor / CELL_SIZE);
            vec2 mc = floor(mouse_cursor / CELL_SIZE);
            if (all(equal(cpos, ivec2(ec))) || all(equal(cpos, ivec2(mc)))) {
                seed = 1.0;
            }

            stateA[idx(ox,oy)] = (seed > 0.82) ? 1.0 : 0.0;
        }
    }

    // Evolve local grid
    int steps = gen % MAX_STEPS;
    for (int s=0; s<MAX_STEPS; s++) {
        if (s >= steps) break;
        int r = MAX_STEPS - s;
        for (int oy=-r; oy<=r; oy++) {
            for (int ox=-r; ox<=r; ox++) {
                int n = 0;
                n += int(stateA[idx(ox-1,oy-1)]);
                n += int(stateA[idx(ox  ,oy-1)]);
                n += int(stateA[idx(ox+1,oy-1)]);
                n += int(stateA[idx(ox-1,oy  )]);
                n += int(stateA[idx(ox+1,oy  )]);
                n += int(stateA[idx(ox-1,oy+1)]);
                n += int(stateA[idx(ox  ,oy+1)]);
                n += int(stateA[idx(ox+1,oy+1)]);

                float alive = stateA[idx(ox,oy)];
                float next  = (alive > 0.5)
                              ? ((n == 2 || n == 3) ? 1.0 : 0.0)
                              : ((n == 3) ? 1.0 : 0.0);
                stateB[idx(ox,oy)] = next;
            }
        }
        // swap
        for (int oy=-r; oy<=r; oy++) {
            for (int ox=-r; ox<=r; ox++) {
                stateA[idx(ox,oy)] = stateB[idx(ox,oy)];
            }
        }
    }

    // Final cell state
    float aliveFinal = stateA[idx(0,0)];

    // Color
    vec3 col = vec3(0.05); // background
    if (aliveFinal > 0.5) {
        float hue = hash21(vec2(cell) * 0.17 + time * 0.05);
        col = hsv2rgb(vec3(hue, 0.8, 1.0));
    }

    return vec4(col, 1.0);
}
