// how to:
// the parameter "cs" is a screen coordinate - it ranges from (0, 0) in the top left
// to (1.0, 1.0) in the bottom right
// available uniforms:
// vec2 resolution - display resolution in pixels (it's 1920x1080 :3)
// float time - time in seconds since shader started
// float chat_time - timestamp (in seconds since shader started) of last chat message
// float tracking_mouth - how open my mouth is (1.0 = Fully Open, 0.0 = Fully Antiopen)
// vec2 tracking_eyes - how open each eye is (1.0 = Fully Open Also)
// vec2 emacs_cursor - position of my emacs cursor on screen (in pixels)
// vec2 mouse_cursor - position of my mouse cursor on screen (in pixels)
// int heartrate - current rate at which my heart is beating (in Hz)
vec4 shade(vec2 cs) {
    return vec4(0.0, 1.0, 0.0, 1.0);
}