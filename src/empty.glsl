// how to:
// the parameter "cs" is a screen coordinate - it ranges from (0, 0) in the top left
// to (1.0, 1.0) in the bottom right
// available uniforms:
// float time - time in seconds since shader started
// vec2 resolution - display resolution in pixels (it's 1920x1080 :3)
// float chat_time - timestamp (in seconds since shader started) of last chat message
vec4 shade(vec2 cs) {
    return vec4(0.0, 1.0, 0.0, 1.0);
}