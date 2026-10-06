# Copyright (C) 2026 The ArkUI Project
# SPDX-License-Identifier: Apache-2.0

BEGIN {
    intro_frames = 72;
    loop_frames = 90;
    pi = atan2(0, -1);
}

# Read the hand-drawn paths, rather than rasterizing the reference artwork.
/<path id=/ {
    id = $0;
    sub(/^.*id="/, "", id);
    sub(/".*/, "", id);
    shape = $0;
    sub(/^.* d="/, "", shape);
    sub(/".*/, "", shape);
    ids[++shape_count] = id;
    paths[id] = shape;
}

function clamp(value, low, high) {
    return value < low ? low : value > high ? high : value;
}

function ease(value) {
    value = clamp(value, 0, 1);
    return value * value * (3 - 2 * value);
}

function path(id, x, y, opacity, fill) {
    if (opacity < 0.0001) return;
    printf "push graphic-context\ntranslate %.4f,%.4f\nfill-opacity %.4f\nfill '%s'\npath '%s'\npop graphic-context\n",
        x, y, opacity, fill, paths[id] > output;
}

function circle(x, y, radius, opacity, fill) {
    if (opacity < 0.0001) return;
    printf "push graphic-context\nfill-opacity %.4f\nfill '%s'\ncircle %.4f,%.4f %.4f,%.4f\npop graphic-context\n",
        opacity, fill, x, y, x + radius, y > output;
}

function bar(width, radius, opacity, fill) {
    if (opacity < 0.0001 || width < 0.01) return;
    printf "push graphic-context\nfill-opacity %.4f\nfill '%s'\nroundrectangle %.4f,%.4f %.4f,%.4f %.4f,%.4f\npop graphic-context\n",
        opacity, fill, 196 - width / 2 - radius, 94.5 - radius,
        196 + width / 2 + radius, 97 + radius, radius + 1.25, radius + 1.25 > output;
}

function light_position(progress,    angle, arrival) {
    if (progress <= 0.65) {
        angle = pi + pi * ease(progress / 0.65);
        light_x = 196 + 27 * cos(angle);
        light_y = 52 - 27 * sin(angle);
    } else {
        arrival = ease((progress - 0.65) / 0.35);
        light_x = 223 - 27 * arrival;
        light_y = 52 + 43.75 * arrival;
    }
}

function render(part, frame,    is_intro, phase, arrival, scale, bar_arrival,
        strength, progress, light_opacity, layer, trail, shape_index) {
    is_intro = part == "part0";
    phase = is_intro ? 0 : 2 * pi * frame / loop_frames;
    arrival = is_intro ? ease((frame - 14) / 43) : 1;
    scale = 2.016 * (1 + 0.03 * (1 - arrival));
    bar_arrival = is_intro ? ease((frame - 28) / 29) : 1;
    strength = 0.9 + 0.1 * sin(phase);
    output = sprintf("%s/%s/%04d.mvg", destination, part, frame);
    print "push graphic-context\nviewbox 0 0 900 300" > output;
    printf "scale %.6f,%.6f\nfill '#000000'\nrectangle 0,0 900,300\n",
        frame_width / 900, frame_height / 300 > output;
    printf "push graphic-context\ntranslate 450,150\nscale %.4f,%.4f\ntranslate -125,-48\n",
        scale, scale > output;

    # The complete wordmark settles once, then stays still throughout the loop.
    for (shape_index = 1; shape_index <= shape_count; shape_index++) {
        path(ids[shape_index], 0.8, 0.4, arrival, "#63758a");
    }
    for (shape_index = 1; shape_index <= shape_count; shape_index++) {
        path(ids[shape_index], 0, 0, arrival, "#f4f6fa");
    }

    # A blue light follows the U bowl and gathers into its underline.
    if (is_intro) {
        progress = clamp((frame - 4) / 39, 0, 1);
        light_opacity = ease((frame - 4) / 7) * (1 - ease((frame - 43) / 13));
        for (trail = 10; trail >= 1; trail--) {
            light_position(clamp(progress - trail * 0.018, 0, 1));
            circle(light_x, light_y, 1.7, light_opacity * (11 - trail) / 70, "#1f69ff");
        }
        light_position(progress);
        for (layer = 12; layer >= 1; layer--) {
            circle(light_x, light_y, 1.5 + layer * 0.5, light_opacity * 0.025, "#1f69ff");
        }
        circle(light_x, light_y, 1.7, light_opacity, "#4f8fff");
        circle(light_x, light_y, 0.7, light_opacity * 0.8, "#c9e3ff");
    }

    # Layered vector outlines provide a soft glow without raster gradients.
    for (layer = 12; layer >= 1; layer--) {
        bar(27 * bar_arrival, layer * 0.4, bar_arrival * strength * 0.012, "#1f69ff");
    }
    bar(27 * bar_arrival, 0, bar_arrival * strength, "#1f69ff");
    print "pop graphic-context\npop graphic-context" > output;
    close(output);
}

END {
    if (shape_count != 7 || !paths["a"] || !paths["a-foot"] || !paths["i"]) {
        print "Invalid ArkUI boot wordmark" > "/dev/stderr";
        exit 1;
    }
    for (frame_number = 0; frame_number < intro_frames; frame_number++) render("part0", frame_number);
    for (frame_number = 0; frame_number < loop_frames; frame_number++) render("part1", frame_number);
}
