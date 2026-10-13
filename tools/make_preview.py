# -*- coding: utf-8 -*-
"""Monta el vídeo de vista previa de la App Store a partir de lo grabado con store_media.gd.

Uso: python tools/make_preview.py build/preview/es_iphone
Lee los fotogramas (f00000000.png...) y segments.txt de esa carpeta, une los trozos útiles
y escribe <carpeta>.mp4: H.264, 30 fps y una pista de audio estéreo en silencio (App Store
Connect exige que el vídeo tenga audio).
"""
import os
import subprocess
import sys

FPS = 30


def ffmpeg_exe():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


def main(folder):
    folder = folder.rstrip("/\\")
    with open(os.path.join(folder, "segments.txt")) as f:
        segments = [tuple(map(int, line.split())) for line in f if line.strip()]

    args = [ffmpeg_exe(), "-y", "-loglevel", "error"]
    for start, end in segments:
        args += ["-framerate", str(FPS), "-start_number", str(start), "-i",
                 os.path.join(folder, "f%08d.png")]
    args += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100"]

    # Cada trozo: solo sus fotogramas; luego se unen en orden.
    parts = []
    for i, (start, end) in enumerate(segments):
        parts.append("[%d:v]trim=end_frame=%d,setpts=PTS-STARTPTS[v%d]" % (i, end - start, i))
    joined = "".join("[v%d]" % i for i in range(len(segments)))
    graph = ";".join(parts) + ";%sconcat=n=%d:v=1:a=0,format=yuv420p[out]" % (joined, len(segments))

    total = sum(end - start for start, end in segments) / FPS
    out = folder + ".mp4"
    args += ["-filter_complex", graph, "-map", "[out]", "-map", "%d:a" % len(segments),
             "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-b:v", "10M",
             "-maxrate", "12M", "-bufsize", "20M", "-r", str(FPS),
             "-c:a", "aac", "-b:a", "256k", "-t", "%.3f" % total,
             "-movflags", "+faststart", out]
    subprocess.run(args, check=True)
    print("%s  (%.1f s)" % (out, total))


if __name__ == "__main__":
    main(sys.argv[1])
