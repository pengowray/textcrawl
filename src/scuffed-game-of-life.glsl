// Conway's Game of Life - Local Simulation, cursor seeding
// Works without persistent buffers by computing each cell's state
// from initial seed and evolving locally up to N steps.

const float CELL_SIZE = 32.0; // pixels per cell
const float STEP_TIME = 0.3; // seconds per generation
const int   MAX_STEPS = 5;   // number of generations simulated per pixel

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0., 1./3., 2./3.)) * 6. - 3.);
    return c.z * mix(vec3(1.), clamp(p - 1., 0., 1.), c.y);
}

const int S = 2*MAX_STEPS+1;
int idx(int x, int y) { return (y+MAX_STEPS)*S + (x+MAX_STEPS); }

vec4 shade(vec2 cs) {
    vec2 pixel = cs * resolution;
    ivec2 cell = ivec2(floor(pixel / CELL_SIZE));
    ivec2 gridSize = ivec2(floor(resolution / CELL_SIZE));

    // Each cell gets its own cycle offset
    float offsetSeed = hash21(vec2(cell) * 0.97);
    int cycleOffset = int(floor(offsetSeed * float(MAX_STEPS)));

    // Which generation for THIS cell?
    int globalStep = int(floor(time / STEP_TIME));
    int stepWithOffset = (globalStep + cycleOffset) % MAX_STEPS;
    int cycle = (globalStep + cycleOffset) / MAX_STEPS;

    // Storage
    float stateA[S*S];
    float stateB[S*S];

    // Initial seed unique to this cell's cycle
    for (int oy=-MAX_STEPS; oy<=MAX_STEPS; oy++) {
        for (int ox=-MAX_STEPS; ox<=MAX_STEPS; ox++) {
            ivec2 cpos = cell + ivec2(ox, oy);
            cpos = (cpos + gridSize) % gridSize;

            float seed = hash21(vec2(cpos) * 0.73 + float(cycle) * 0.37);

            // Force alive under cursor
            vec2 ec = floor(emacs_cursor / CELL_SIZE);
            vec2 mc = floor(mouse_cursor / CELL_SIZE);
            if (all(equal(cpos, ivec2(ec))) || all(equal(cpos, ivec2(mc)))) {
                seed = 1.0;
            }

            stateA[idx(ox,oy)] = (seed > 0.82) ? 1.0 : 0.0;
        }
    }

    // Evolve for stepWithOffset generations
    for (int s=0; s<MAX_STEPS; s++) {
        if (s >= stepWithOffset) break;
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
        // swap buffers
        for (int oy=-r; oy<=r; oy++) {
            for (int ox=-r; ox<=r; ox++) {
                stateA[idx(ox,oy)] = stateB[idx(ox,oy)];
            }
        }
    }

    // Final cell state
    float aliveFinal = stateA[idx(0,0)];

    // Coloring
    vec3 col = vec3(0.05);
    if (aliveFinal > 0.5) {
        float hue = hash21(vec2(cell) * 0.17 + float(cycle) * 0.37);
        col = hsv2rgb(vec3(hue, 0.8, 1.0));
    }

    return vec4(col, 1.0);
}
