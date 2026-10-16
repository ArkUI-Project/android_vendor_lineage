# Copyright (C) 2026 The ArkUI Project
# SPDX-License-Identifier: Apache-2.0

BEGIN {
    fps = 50;
    intro_frames = 110;
    loop_frames = 72;
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

function minimum(a, b) { return a < b ? a : b; }
function maximum(a, b) { return a > b ? a : b; }
function ceiling(value) { return int(value) + (value > int(value)); }

function bezier_coordinate(t, a, b) {
    return 3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t;
}

function cubic_bezier(progress, x1, y1, x2, y2,    low, high, mid, iteration) {
    progress = clamp(progress, 0, 1);
    if (progress == 0 || progress == 1) return progress;
    low = 0;
    high = 1;
    for (iteration = 0; iteration < 20; iteration++) {
        mid = (low + high) / 2;
        if (bezier_coordinate(mid, x1, x2) < progress) low = mid;
        else high = mid;
    }
    return bezier_coordinate((low + high) / 2, y1, y2);
}

function decelerate(progress) {
    return cubic_bezier(progress, 0.22, 0.55, 0.30, 1);
}

function set_crop(part, padding,    right, bottom) {
    crop_x[part] = int(maximum(0, logo_x - padding));
    crop_y[part] = int(maximum(0, logo_y - padding));
    right = ceiling(minimum(frame_width, logo_x + 250 * logo_scale + padding));
    bottom = ceiling(minimum(frame_height, maximum(logo_y + 80 * logo_scale + padding,
            relay_y + relay_height + design_unit)));
    crop_width[part] = maximum(1, right - crop_x[part]);
    crop_height[part] = maximum(1, bottom - crop_y[part]);
    printf "%s\t%d\t%d\n", part, crop_width[part], crop_height[part] >> geometry_plan;
}

function begin_canvas(width, height, x, y, opaque) {
    printf "push graphic-context\nviewbox 0 0 %d %d\n", width, height > output;
    if (opaque) {
        printf "fill '#000000'\nrectangle 0,0 %d,%d\n", width, height > output;
    }
    printf "translate %.8f,%.8f\n", -x, -y > output;
}

function end_canvas() {
    print "pop graphic-context" > output;
    close(output);
}

function update_wordmark(time,    entrance_time, entrance, movement, rest_time, rest_ease) {
    entrance_time = clamp((time - 0.06) / 0.34, 0, 1);
    entrance = decelerate(entrance_time);
    movement = cubic_bezier((time - 0.52) / 0.46, 0.32, 0, 0.2, 1);
    a_scale = logo_scale * (0.82 + 0.26 * entrance - 0.08 * movement);
    a_x = frame_width / 2 + (logo_x + 37 * logo_scale - frame_width / 2) * movement;
    a_y = logo_y + 40 * logo_scale;
    a_opacity = ease(entrance_time);
    a_blur = (7 * (1 - entrance) + sin(atan2(0, -1) * movement) * 1.05) * a_scale;
    rest_time = clamp((time - 0.74) / 0.56, 0, 1);
    rest_ease = decelerate(rest_time);
    rest_scale = 0.70 + 0.30 * rest_ease;
    rest_offset = -27 * (1 - rest_ease);
    rest_opacity = cubic_bezier(rest_time, 0.2, 0.45, 0.3, 1);
    rest_blur = 5.5 * (1 - rest_ease) * logo_scale * rest_scale;
}

function draw_glyphs(role,    shape_index, id, is_a, opacity) {
    opacity = role == "a" ? a_opacity : rest_opacity;
    if (opacity < 0.0001) return;
    printf "push graphic-context\nfill '#f4f6fa'\nfill-opacity %.8f\n", opacity > output;
    if (role == "a") {
        printf "translate %.8f,%.8f\nscale %.8f,%.8f\ntranslate -37,-40\n",
            a_x, a_y, a_scale, a_scale > output;
    } else {
        printf "translate %.8f,%.8f\nscale %.8f,%.8f\ntranslate %.8f,40\nscale %.8f,%.8f\ntranslate -82,-40\n",
            logo_x, logo_y, logo_scale, logo_scale, 82 + rest_offset,
            rest_scale, rest_scale > output;
    }
    for (shape_index = 1; shape_index <= shape_count; shape_index++) {
        id = ids[shape_index];
        is_a = id == "a" || id == "a-foot";
        if ((role == "a" && is_a) || (role == "rest" && !is_a)) {
            printf "path '%s'\n", paths[id] > output;
        }
    }
    print "pop graphic-context" > output;
}

function make_layer(role, frame, sigma,    saved_output, layer_file, image_file) {
    saved_output = output;
    layer_file = sprintf("%s/%s-%04d.mvg", layer_destination, role, frame);
    output = layer_file;
    begin_canvas(layer_width, layer_height, layer_x, layer_y, 0);
    draw_glyphs(role);
    end_canvas();
    printf "%s\t%d\t%d\t%.8f\n", layer_file, layer_width, layer_height, sigma >> layer_plan;
    image_file = layer_file;
    sub(/\.mvg$/, ".png", image_file);
    output = saved_output;
    return image_file;
}

function draw_role(role, frame, sigma, opacity,    image_file) {
    if (opacity < 0.0001) return;
    if (sigma < 0.01) {
        draw_glyphs(role);
        return;
    }
    image_file = make_layer(role, frame, sigma);
    printf "push graphic-context\nfill-opacity 1\nimage over %.8f,%.8f %d,%d '%s'\npop graphic-context\n",
        layer_x, layer_y, layer_width, layer_height, image_file > output;
}

function rounded_line(left, right, opacity, fill) {
    if (opacity < 0.0001) return;
    printf "push graphic-context\nfill '%s'\nfill-opacity %.8f\nroundrectangle %.8f,%.8f %.8f,%.8f %.8f,%.8f\npop graphic-context\n",
        fill, opacity, left, relay_y, right, relay_y + relay_height,
        relay_height / 2, relay_height / 2 > output;
}

function draw_relay(time,    elapsed, motion, step, phase, from, to, source_left,
        target_left, extend, release, active_left, active_right, opacity, track) {
    elapsed = time - 1.90;
    if (elapsed <= 0) return;
    opacity = ease(elapsed / 0.30);
    motion = maximum(0, elapsed - 0.30) / 0.36;
    step = int(motion) % 4;
    phase = motion - int(motion);
    from = relay_order[step];
    to = relay_order[(step + 1) % 4];
    source_left = relay_x + from * relay_pitch;
    target_left = relay_x + to * relay_pitch;
    extend = cubic_bezier(phase / 0.56, 0.20, 0, 0.10, 1);
    release = cubic_bezier((phase - 0.30) / 0.70, 0.32, 0, 0.20, 1);
    active_left = source_left + (target_left - source_left) * (to > from ? release : extend);
    active_right = source_left + relay_width + \
            (target_left - source_left) * (to > from ? extend : release);
    for (track = 0; track < 3; track++) {
        rounded_line(relay_x + track * relay_pitch,
                relay_x + track * relay_pitch + relay_width, opacity, "#303a46");
    }
    rounded_line(active_left, active_right, opacity, "#d3dfed");
}

function render(part, frame, time,    trim_file, x, y, right, bottom) {
    update_wordmark(time);
    output = sprintf("%s/%s/%04d.mvg", destination, part, frame);
    begin_canvas(crop_width[part], crop_height[part], crop_x[part], crop_y[part], 1);
    draw_relay(time);
    draw_role("rest", frame, rest_blur, rest_opacity);
    draw_role("a", frame, a_blur, a_opacity);
    end_canvas();

    # trim.txt uses logical display pixels even when textures are rendered at half resolution.
    x = int(crop_x[part] * logical_width / frame_width + 0.5);
    y = int(crop_y[part] * logical_height / frame_height + 0.5);
    right = int((crop_x[part] + crop_width[part]) * logical_width / frame_width + 0.5);
    bottom = int((crop_y[part] + crop_height[part]) * logical_height / frame_height + 0.5);
    trim_file = sprintf("%s/%s/trim.txt", destination, part);
    printf "%dx%d+%d+%d\n", right - x, bottom - y, x, y >> trim_file;
}

END {
    if (shape_count != 7 || !paths["a"] || !paths["a-foot"] || !paths["i"]) {
        print "Invalid ArkUI boot wordmark" > "/dev/stderr";
        exit 1;
    }
    design_unit = minimum(frame_width, frame_height) / 540;
    logo_scale = minimum(frame_width, frame_height) * 0.56 / 250;
    logo_x = (frame_width - 250 * logo_scale) / 2;
    logo_y = frame_height / 2 - 48 * logo_scale;
    relay_width = 26 * design_unit;
    relay_pitch = 34 * design_unit;
    relay_height = 4.5 * design_unit;
    relay_x = (frame_width - 94 * design_unit) / 2;
    relay_y = frame_height - 86 * design_unit;
    relay_order[0] = 0;
    relay_order[1] = 1;
    relay_order[2] = 2;
    relay_order[3] = 1;

    geometry_plan = plan_directory "/geometry.tsv";
    layer_plan = plan_directory "/layers.tsv";
    set_crop("part0", 32 * logo_scale);
    set_crop("part1", maximum(1, 2 * design_unit));
    layer_x = crop_x["part0"];
    layer_y = crop_y["part0"];
    layer_width = crop_width["part0"];
    layer_height = maximum(1, ceiling(minimum(frame_height, logo_y + 112 * logo_scale)) - layer_y);

    for (frame_number = 0; frame_number < intro_frames; frame_number++) {
        render("part0", frame_number, frame_number / fps);
    }
    # The loop begins at exactly 2.20 s; the wordmark is settled and the relay is at its start.
    for (frame_number = 0; frame_number < loop_frames; frame_number++) {
        render("part1", frame_number, (intro_frames + frame_number) / fps);
    }
}
