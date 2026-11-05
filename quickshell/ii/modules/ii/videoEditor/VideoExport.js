.pragma library

// The ffmpeg arguments for what the video editor exports. Kept apart from the
// window so they can be run and checked on their own.
//
// o: {
//   input, output,
//   format: "mp4" | "gif",
//   start, end:  seconds of the part to keep,
//   speed:       0.5 .. 2 (the audio filter atempo takes that range),
//   mute:        drop the sound,
//   crop:        null, or { x, y, w, h } in the video's own pixels
// }

function evenFloor(n) {
    return Math.max(2, Math.floor(n / 2) * 2);
}

// Seconds of the output: the kept part, sped up or slowed down
function outputSeconds(o) {
    return Math.max(0.01, (o.end - o.start) / o.speed);
}

function buildArgs(o) {
    const keep = Math.max(0.05, o.end - o.start);
    const filters = [];
    if (o.crop) {
        // Even sizes: H.264 in 4:2:0 cannot take odd ones
        filters.push("crop=" + evenFloor(o.crop.w) + ":" + evenFloor(o.crop.h)
            + ":" + Math.max(0, Math.round(o.crop.x)) + ":" + Math.max(0, Math.round(o.crop.y)));
    }
    if (o.speed !== 1) filters.push("setpts=PTS/" + o.speed);

    const args = ["-y", "-v", "error", "-progress", "pipe:1", "-nostats",
        // Both the seek and the length belong to the input: as an output option
        // the length would count the sped-up or slowed-down time instead.
        "-ss", String(o.start), "-t", String(keep), "-i", o.input];

    if (o.format === "gif") {
        filters.push("fps=15");
        filters.push("scale='min(iw,720)':-2:flags=lanczos");
        filters.push("split[a][b];[a]palettegen[p];[b][p]paletteuse");
        args.push("-vf", filters.join(","), "-an", "-loop", "0", o.output);
        return args;
    }

    if (filters.length > 0) args.push("-vf", filters.join(","));
    if (o.mute) {
        args.push("-an");
    } else {
        if (o.speed !== 1) args.push("-af", "atempo=" + o.speed);
        args.push("-c:a", "aac", "-b:a", "160k");
    }
    args.push("-c:v", "libx264", "-crf", "20", "-preset", "veryfast", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", o.output);
    return args;
}

// "01:23" or "1:02:03" from seconds
function formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds));
    const h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60), s = total % 60;
    const two = n => (n < 10 ? "0" : "") + n;
    return (h > 0 ? h + ":" + two(m) : two(m)) + ":" + two(s);
}
