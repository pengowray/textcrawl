#define CHAR_WIDTH 0.08
#define CHAR_HEIGHT 0.1
#define SPACING 0.02
#define THICKNESS 0.25

// Fixed 8-character message: HH:MM:SS
#define MESSAGE_LENGTH 8

// Return fixed message length.
int getMessageLength() {
    return MESSAGE_LENGTH;
}

// Convert the live time (in seconds) into a fixed HH:MM:SS text.
// Hours, minutes, and seconds are computed from the global `time` variable.
int getCharAt(int index) {
    int totalSeconds = int(time);
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours   = (totalSeconds / 3600) % 24;
    
    // Convert digit to ASCII ('0' is 48)
    if (index == 0) return 48 + (hours / 10);
    if (index == 1) return 48 + (hours % 10);
    if (index == 2) return 58; // colon ':'
    if (index == 3) return 48 + (minutes / 10);
    if (index == 4) return 48 + (minutes % 10);
    if (index == 5) return 58; // colon ':'
    if (index == 6) return 48 + (seconds / 10);
    if (index == 7) return 48 + (seconds % 10);
    return 32; // fallback to space
}


// ===================================================================
// SHADER CODE
// ===================================================================

const float B = 0.25; // Bevel amount
const int SEGMENT_COUNT = 28;
const mat2 SEGMENTS[SEGMENT_COUNT] = mat2[](
    //                                  0x.....0
    mat2(vec2(-1, 1.-B), vec2(-1, -1)),    //  0: left
    mat2(vec2(B-1., 1), vec2(.5, 1)),        //  1: top(left)
    mat2(vec2(.5, 1), vec2(1, 1)),           //  2: top(right)
    mat2(vec2(1, 1), vec2(1, 0)),            //  3: right(top)
    //                                  0x....0.
    mat2(vec2(1, 0), vec2(1, B-1.)),         //  4: right(bottom)
    mat2(vec2(1.-B, -1), vec2(-1, -1)),      //  5: bottom
    mat2(vec2(0, 1), vec2(0, -1)),           //  6: vertical
    mat2(vec2(.5, 0), vec2(-1, 0)),          //  7: horizontal(left)
    //                                  0x...0..
    mat2(vec2(.5, 0), vec2(1, 0)),           //  8: horizontal(right)
    mat2(vec2(.5, 1), vec2(.5, 0)),          //  9: B R
    mat2(vec2(.5, 1), vec2(1, 0)),           // 10: D
    mat2(vec2(B-1., 1), vec2(1.-B, -1)),      // 11: N
    //                                  0x..0...
    mat2(vec2(-1, 1.-B), vec2(1., B-1.)),     // 12: S
    mat2(vec2(-1, 1.-B), vec2(1.-B, -1.)),    // 13: V
    mat2(vec2(1, 1), vec2(-1, -1)),           // 14: Z
    mat2(vec2(1, 1), vec2(0, 0)),             // 15: Y K tr
    //                                  0x.0....
    mat2(vec2(-1, 1.-B), vec2(0, 0)),         // 16: Y tl
    mat2(vec2(0, 0), vec2(0, -1)),            // 17: vertical(bottom)
    mat2(vec2(1, 1), vec2(-1, -1)),           // 18: X Z tr bl diag
    mat2(vec2(-1, 0), vec2(-1, -1)),          // 19: left(bottom)
    //                                  0x0.....
    mat2(vec2(-1, 1.-B), vec2(-1, 0)),        // 20: left(top)
    mat2(vec2(0, -.99), vec2(0, -1)),         // 21: dot (for period)
    mat2(vec2(0, 1), vec2(0, 0)),             // 22: vertical(top)
    //                                  FROM CONTEXT
    mat2(vec2(-1, 1.-B), vec2(B-1., 1)),       // 23: bevel top-left
    mat2(vec2(1, B-1.), vec2(1.-B, -1)),       // 24: bevel bottom-right
    //                                  segment for dash ('-')
    mat2(vec2(-0.5, 0), vec2(0.5, 0)),         // 25: dash
    // 
    mat2(vec2(0, 0.6), vec2(0, 0.62)),        // 26: colon top dot
    mat2(vec2(0, -0.38), vec2(0, -0.4))         // 27: colon bottom dot
);

const int font[43] = int[](
    0x00103F, 0x000040, 0x0801AE, 0x0001BE, 0x100198,
    0x1001B6, 0x0001B1, 0x00011E, 0x0001BF, 0x10019E,
    0x000000, 0x000000, 0x000000, 0x000000, 0x000000, // reserved entries
    0x208006, 0x600000,
    0x00019F, 0x0003B3, 0x000027, 0x000433, 0x0000A7, 0x000087,
    0x000137, 0x000199, 0x000066, 0x00003E, 0x008191, 0x000021,
    0x00005F, 0x000819, 0x00003F, 0x00018F, 0x02003F, 0x000393,
    0x001026, 0x000046, 0x000039, 0x002018, 0x000079, 0x004800,
    0x038000, 0x004026
);

// Convert an ASCII code to a segment bitmask.
// Returns 0 for space (or any unsupported character).
int ascii_to_bitmask(int i) {
    if (i == 32) return 0; // space
    
    // dash '-' (ASCII 45)
    if (i == 45) return (1 << 25);
    
    // period '.' (ASCII 46)
    if (i == 46) return (1 << 21);

    // colon
    if (i == 58) return (1 << 26) | (1 << 27);
    
    // Only support 0–9 and A–Z (upper-case) beyond the above.
    if (i < 48 || i > 90) return 0;
    int l = font[i - 48];
    if ((l & 0x13813) != 0) l += 1 << 23; // bevel tl
    if ((l & 0x03830) != 0) l += 1 << 24; // bevel br
    return l;
}

// Draw a character using the segment bitmask.
float drawChar(vec2 uv, int charCode, float thickness) {
    // Flip Y for proper orientation.
    uv.y = 1.0 - uv.y;
    vec2 g = uv * 2.0 - 1.0; // Map uv from [0,1] to [-1,1]
    
    // Early exit if outside bounds.
    if (abs(g.x) > 1.1 || abs(g.y) > 1.1) {
        return 1.0;
    }
    
    int bitmask = ascii_to_bitmask(charCode);
    float d = 1.0;
    
    // For each segment enabled in the bitmask, compute its distance.
    for (int i = 0; i < SEGMENT_COUNT; i++) {
        if ((bitmask & (1 << i)) != 0) {
            vec2 p1 = SEGMENTS[i][0];
            vec2 p2 = SEGMENTS[i][1];
            vec2 pa = g - p1;
            vec2 ba = p2 - p1;
            float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
            float segDist = length(pa - ba * h);
            d = min(d, segDist);
        }
    }
    
    return smoothstep(thickness, thickness * 1.2, d);
}

// Main shading function.
vec4 shade(vec2 cs) {
    vec2 uv = cs;
    
    // Background gradient.
    vec3 bgColor = mix(vec3(0.05, 0.05, 0.15), vec3(0.1, 0.1, 0.2), cs.y);
    
    int messageLength = getMessageLength();
    // Scroll right-to-left.
    //float scrollOffset = 1.0 - mod(time * 0.3, 1.0 + float(messageLength) * (CHAR_WIDTH + SPACING));
    // fixed:
    float scrollOffset = 1.0 - 0.5 * (1.0 + float(messageLength) * (CHAR_WIDTH + SPACING));
    
    vec4 resultColor = vec4(bgColor, 1.0);
    
    // Draw each character in the message.
    for (int i = 0; i < 50; i++) { // Limit iterations for performance.
        if (i >= messageLength) break;
        int charCode = getCharAt(i);
        if (charCode == 0) continue; // Skip unsupported characters.
        
        // Compute horizontal position with scrolling.
        float charX = scrollOffset + float(i) * (CHAR_WIDTH + SPACING);
        if (charX < -CHAR_WIDTH || charX > 1.0) continue;
        
        // Adjust UV for character placement and size.
        vec2 charUV = (uv - vec2(charX, 0.45)) / vec2(CHAR_WIDTH, CHAR_HEIGHT);
        
        // Optional wave effect.
        float wave = sin(time * 2.0 + float(i) * 0.5) * 0.05;
        charUV.y -= wave;
        
        // Only draw if within bounds.
        if (charUV.x >= 0.0 && charUV.x <= 1.0 && charUV.y >= 0.0 && charUV.y <= 1.0) {
            float charMask = drawChar(charUV, charCode, THICKNESS);
            // Generate a color based on time and character index.
            vec3 charColor = 0.5 + 0.5 * cos(time + float(i) * 0.3 + vec3(0, 2, 4));
            // Optional pulse effect.
            float pulse = 0.7 + 0.3 * sin((time - chat_time) * 3.0);
            charColor *= pulse;
            
            // Blend the character onto the background.
            resultColor.rgb = mix(charColor, resultColor.rgb, charMask);
        }
    }
    
    return resultColor;
}
