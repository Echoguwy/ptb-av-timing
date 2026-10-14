# Video–audio sync example

`Video_Sound_test_Linux_26_9_22.m` plays a 5 Hz half-field checkerboard together with a 50 ms beep, then writes the trigger after the scheduled flip. Run it on the Ubuntu + Psychtoolbox rig described in the manual. Media paths are resolved from this folder, so the working directory does not matter.

| File | Role |
|---|---|
| `half_left_checkerboard_5Hz_1080p.mp4` | Deviant clip: left half flickers |
| `half_bottom_checkerboard_5Hz_1080p.mp4` | Standard clip: bottom half flickers |
| `checker.jpg`, `square.jpg` | Still images loaded by the script |

Both clips are 1920×1080, 30 fps, 1 s. The originals were uncompressed AVI at about 178 MB each. These copies are H.264, CRF 12. The squares are 120 px, so the pattern survives that compression; PTB `OpenMovie` and MATLAB `VideoReader` both read the MP4.
