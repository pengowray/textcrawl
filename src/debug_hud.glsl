
// ===================================================================
// Debug HUD
//
// This shader expects ThrowShade-style uniforms to already exist.
// (They are defined/owned by the host app/loader, not by this file.)
//
// Available uniforms (from the loader):
// - vec2  resolution       display resolution in pixels
// - float time             time in seconds since shader started
// - float chat_time        timestamp (in seconds since shader started) of last chat message
// - float tracking_mouth   how open mouth is (1.0 open, 0.0 closed)
// - vec2  tracking_eyes    how open each eye is (1.0 open, 0.0 closed)
// - vec2  emacs_cursor     emacs cursor position
// - vec2  mouse_cursor     mouse cursor position
// - int   heartrate        current heart rate (bpm)
//
// HUD behavior:
// - Draws a label (line 1) and value(s) (line 2) in the top-left.
// - Cycles to the next uniform every 3 seconds.
//
// Font:
// - Supports A–Z, 0–9, space, '.', ':', '-'
// - Labels avoid underscores (e.g. "CHAT TIME")
// ===================================================================

#define CHAR_WIDTH 0.04
#define CHAR_HEIGHT 0.05
#define SPACING 0.01
#define THICKNESS 0.22

// Field index mapping (used by getLabel*/getValue*):
// 0: resolution
// 1: time
// 2: chat_time
// 3: tracking_mouth
// 4: tracking_eyes
// 5: emacs_cursor
// 6: mouse_cursor
// 7: heartrate
const int FIELD_COUNT = 8;
const int MAX_LINE_CHARS = 32;

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
    // Flip Y for proper orientation
    uv.y = 1.0 - uv.y;
    vec2 g = uv * 2.0 - 1.0; // Map uv from [0,1] to [-1,1]
    
    // Early exit if outside bounds
    if (abs(g.x) > 1.1 || abs(g.y) > 1.1) {
        return 1.0;
    }
    
    int bitmask = ascii_to_bitmask(charCode);
    float d = 1.0;
    
    // For each segment enabled in the bitmask, compute its distance
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

int digitToAscii(int d) {
    return 48 + clamp(d, 0, 9);
}

int intCharFixed(int v, int digits, int posFromLeft) {
    int absV = abs(v);
    float div = pow(10.0, float(digits - 1 - posFromLeft));
    int digit = int(floor(float(absV) / div)) % 10;
    return digitToAscii(digit);
}

int floatCharFixed(float v, int index, int intDigits, int fracDigits) {
    // Layout: [sign][intDigits...][.][fracDigits...]
    // Total length: 1 + intDigits + 1 + fracDigits
    if (index == 0) return (v < 0.0) ? 45 : 32; // '-' or space

    int fracBase = int(pow(10.0, float(fracDigits)) + 0.5);
    float av = abs(v);
    int scaled = int(floor(av * float(fracBase) + 0.5));
    int intPart = scaled / fracBase;
    int fracPart = scaled - intPart * fracBase;

    int intBase = int(pow(10.0, float(intDigits)) + 0.5);
    if (intBase > 0) intPart = intPart % intBase;

    // Integer digits
    if (index >= 1 && index <= intDigits) {
        return intCharFixed(intPart, intDigits, index - 1);
    }

    // Decimal point
    if (index == 1 + intDigits) return 46;

    // Fraction digits
    int fracIndex = index - (2 + intDigits);
    if (fracIndex >= 0 && fracIndex < fracDigits) {
        return intCharFixed(fracPart, fracDigits, fracIndex);
    }

    return 32;
}

int getLabelLength(int field) {
    if (field == 0) return 10; // RESOLUTION
    if (field == 1) return 4;  // TIME
    if (field == 2) return 9;  // CHAT TIME
    if (field == 3) return 14; // TRACKING MOUTH
    if (field == 4) return 13; // TRACKING EYES
    if (field == 5) return 12; // EMACS CURSOR
    if (field == 6) return 12; // MOUSE CURSOR
    if (field == 7) return 9;  // HEARTRATE
    return 0;
}

int getLabelChar(int field, int index) {
    if (field == 0) {
        int msg[10] = int[](82, 69, 83, 79, 76, 85, 84, 73, 79, 78);
        return (index >= 0 && index < 10) ? msg[index] : 0;
    }
    if (field == 1) {
        int msg[4] = int[](84, 73, 77, 69);
        return (index >= 0 && index < 4) ? msg[index] : 0;
    }
    if (field == 2) {
        int msg[9] = int[](67, 72, 65, 84, 32, 84, 73, 77, 69);
        return (index >= 0 && index < 9) ? msg[index] : 0;
    }
    if (field == 3) {
        int msg[14] = int[](84, 82, 65, 67, 75, 73, 78, 71, 32, 77, 79, 85, 84, 72);
        return (index >= 0 && index < 14) ? msg[index] : 0;
    }
    if (field == 4) {
        int msg[13] = int[](84, 82, 65, 67, 75, 73, 78, 71, 32, 69, 89, 69, 83);
        return (index >= 0 && index < 13) ? msg[index] : 0;
    }
    if (field == 5) {
        int msg[12] = int[](69, 77, 65, 67, 83, 32, 67, 85, 82, 83, 79, 82);
        return (index >= 0 && index < 12) ? msg[index] : 0;
    }
    if (field == 6) {
        int msg[12] = int[](77, 79, 85, 83, 69, 32, 67, 85, 82, 83, 79, 82);
        return (index >= 0 && index < 12) ? msg[index] : 0;
    }
    if (field == 7) {
        int msg[9] = int[](72, 69, 65, 82, 84, 82, 65, 84, 69);
        return (index >= 0 && index < 9) ? msg[index] : 0;
    }
    return 0;
}

int getValueLength(int field) {
    if (field == 0) return 13; // X:#### Y:####
    if (field == 1) return 14; // S:[sign][######].[##]
    if (field == 2) return 14; // S:[sign][######].[##]
    if (field == 3) return 8;  // V:[sign][#].[###]
    if (field == 4) return 17; // L:[sign][#].[###] R:[sign][#].[###]
    if (field == 5) return 13; // X:#### Y:####
    if (field == 6) return 13; // X:#### Y:####
    if (field == 7) return 6;  // HZ:###
    return 0;
}

int getValueChar(int field, int index) {
    if (field == 0) {
        // X:#### Y:####
        int rx = int(resolution.x + 0.5);
        int ry = int(resolution.y + 0.5);
        if (index == 0) return 88; // X
        if (index == 1) return 58; // :
        if (index >= 2 && index <= 5) return intCharFixed(rx, 4, index - 2);
        if (index == 6) return 32; // space
        if (index == 7) return 89; // Y
        if (index == 8) return 58; // :
        if (index >= 9 && index <= 12) return intCharFixed(ry, 4, index - 9);
        return 32;
    }

    if (field == 1) {
        // S: + time
        if (index == 0) return 83; // S
        if (index == 1) return 58; // :
        return floatCharFixed(time, index - 2, 6, 2);
    }

    if (field == 2) {
        // S: + chat_time
        if (index == 0) return 83; // S
        if (index == 1) return 58; // :
        return floatCharFixed(chat_time, index - 2, 6, 2);
    }

    if (field == 3) {
        // V: + tracking_mouth
        if (index == 0) return 86; // V
        if (index == 1) return 58; // :
        return floatCharFixed(tracking_mouth, index - 2, 1, 3);
    }

    if (field == 4) {
        // L:val R:val
        if (index == 0) return 76; // L
        if (index == 1) return 58; // :
        if (index >= 2 && index <= 7) return floatCharFixed(tracking_eyes.x, index - 2, 1, 3);
        if (index == 8) return 32; // space
        if (index == 9) return 82; // R
        if (index == 10) return 58; // :
        if (index >= 11 && index <= 16) return floatCharFixed(tracking_eyes.y, index - 11, 1, 3);
        return 32;
    }

    if (field == 5) {
        // X:#### Y:####
        int cx = int(emacs_cursor.x + 0.5);
        int cy = int(emacs_cursor.y + 0.5);
        if (index == 0) return 88; // X
        if (index == 1) return 58; // :
        if (index >= 2 && index <= 5) return intCharFixed(cx, 4, index - 2);
        if (index == 6) return 32;
        if (index == 7) return 89; // Y
        if (index == 8) return 58;
        if (index >= 9 && index <= 12) return intCharFixed(cy, 4, index - 9);
        return 32;
    }

    if (field == 6) {
        // X:#### Y:####
        int cx = int(mouse_cursor.x + 0.5);
        int cy = int(mouse_cursor.y + 0.5);
        if (index == 0) return 88; // X
        if (index == 1) return 58; // :
        if (index >= 2 && index <= 5) return intCharFixed(cx, 4, index - 2);
        if (index == 6) return 32;
        if (index == 7) return 89; // Y
        if (index == 8) return 58;
        if (index >= 9 && index <= 12) return intCharFixed(cy, 4, index - 9);
        return 32;
    }

    if (field == 7) {
        // HZ:###
        int hz = clamp(heartrate, 0, 999);
        if (index == 0) return 72; // H
        if (index == 1) return 90; // Z
        if (index == 2) return 58; // :
        if (index >= 3 && index <= 5) return intCharFixed(hz, 3, index - 3);
        return 32;
    }

    return 32;
}

vec3 drawLine(vec2 uv, vec2 origin, int field, bool isLabel, vec3 bg) {
    int len = isLabel ? getLabelLength(field) : getValueLength(field);

    vec3 outColor = bg;
    for (int i = 0; i < MAX_LINE_CHARS; i++) {
        if (i >= len) break;
        int ch = isLabel ? getLabelChar(field, i) : getValueChar(field, i);

        vec2 charPos = origin + vec2(float(i) * (CHAR_WIDTH + SPACING), 0.0);
        vec2 charUV = (uv - charPos) / vec2(CHAR_WIDTH, CHAR_HEIGHT);
        if (charUV.x < 0.0 || charUV.x > 1.0 || charUV.y < 0.0 || charUV.y > 1.0) continue;

        float mask = drawChar(charUV, ch, THICKNESS);
        vec3 fg = vec3(0.95);
        outColor = mix(fg, outColor, mask);
    }
    return outColor;
}

// Main shading function.
vec4 shade(vec2 cs) {
    vec2 uv = cs;

    // Background gradient.
    vec3 bgColor = mix(vec3(0.05, 0.05, 0.15), vec3(0.1, 0.1, 0.2), cs.y);

    int field = int(floor(time / 3.0)) % FIELD_COUNT;

    vec2 labelPos = vec2(0.02, 0.02);
    vec2 valuePos = labelPos + vec2(0.0, CHAR_HEIGHT + 0.015);

    vec3 col = bgColor;
    col = drawLine(uv, labelPos, field, true, col);
    col = drawLine(uv, valuePos, field, false, col);

    return vec4(col, 1.0);
}