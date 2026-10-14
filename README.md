# High-precision audiovisual stimulus timing with Psychtoolbox

Bilingual, beginner-friendly manual for presenting visual and auditory stimuli with stable, measurable onset timing. Written for MEG/EEG labs that timestamp stimuli with a trigger and need the physical onset (light on the screen, sound at the ear) to stay within about 1 ms of jitter.

Measured on the rig described in the manual: Ubuntu 20.04, a discrete AMD GPU, Psychtoolbox, photodiode + microphone + NI acquisition at 10 kHz.

| | Read online | Word |
|---|---|---|
| 中文 | [高时间精度视听觉刺激呈现说明书](高时间精度视听觉刺激呈现说明书.md) | [docx](高时间精度视听觉刺激呈现说明书.docx) |
| English | [High-Precision AV Stimulation Manual](High-Precision-AV-Stimulation-Manual.md) | [docx](High-Precision-AV-Stimulation-Manual.docx) |


## Examples

| Folder | What it shows |
|---|---|
| [examples/Image_Sound_Sync](examples/Image_Sound_Sync) | Still image plus beep, scheduled on the same frame (`audio_visual_delay_test_Linux_25_6_13.m`) |
| [examples/Video_Sound_Sync](examples/Video_Sound_Sync) | Checkerboard movie plus beep (`Video_Sound_test_Linux_26_9_22.m`). Clips recompressed from uncompressed 1080p AVI to H.264 CRF 12 MP4 |

Paths in both scripts are relative to the script file.

Forum thread: [Visual and auditory jitter under 1 ms](https://psychtoolbox.discourse.group/t/visual-and-auditory-jitter-under-1-ms-light-sound-delay-within-0-5-ms-7-rules-that-held-up/5819). The text that was posted is in [discourse-post.md](discourse-post.md).
