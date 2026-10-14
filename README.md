# High-precision audiovisual stimulus timing with Psychtoolbox

Bilingual, beginner-friendly manual for presenting visual and auditory stimuli with stable, measurable onset timing. Written for MEG/EEG labs that timestamp stimuli with a trigger and need the physical onset (light on the screen, sound at the ear) to stay within about 1 ms of jitter.

Measured on the rig described in the manual: Ubuntu 20.04, a discrete AMD GPU, Psychtoolbox, photodiode + microphone + NI acquisition at 10 kHz.

| | Read online | Word |
|---|---|---|
| 中文 | [高时间精度视听觉刺激呈现说明书](高时间精度视听觉刺激呈现说明书.md) | [docx](高时间精度视听觉刺激呈现说明书.docx) |
| English | [High-Precision AV Stimulation Manual](High-Precision-AV-Stimulation-Manual.md) | [docx](High-Precision-AV-Stimulation-Manual.docx) |

The numbers in the manual use one convention throughout: send the trigger first, then schedule the stimulus 15 ms later. A flip-then-trigger measurement reads about one frame smaller. Compare setups only when the convention matches.

## Example

[examples/Video_Sound_Sync](examples/Video_Sound_Sync) is the Linux video–audio sync script (`Video_Sound_test_Linux_26_9_22.m`) with the two checkerboard clips and the still images it loads. Paths are relative to the script. The clips were recompressed from uncompressed 1080p AVI (~178 MB each) to H.264 CRF 12 MP4.
