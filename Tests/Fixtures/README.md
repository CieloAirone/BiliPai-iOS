Synthetic four-second testsrc video and 440 Hz sine wave, generated locally with FFmpeg; no third-party media content.

Video: libx264, 160x90, 24 fps, yuv420p, GOP 24, `-movflags +dash+global_sidx`.
Audio: AAC 48k, 44100 Hz, `-movflags +dash+global_sidx`.
Fixtures exercise actual AVPlayer playback of SegmentBase ranges exposed through the local HLS bridge.
