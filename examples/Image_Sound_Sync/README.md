# Still-image and audio sync example

`audio_visual_delay_test_Linux_25_6_13.m` presents a still image and a 50 ms beep on the same scheduled frame, then writes the trigger after the flip. There is no movie. Run it on the Ubuntu + Psychtoolbox rig described in the manual. The image path is resolved from this folder.

The script loads `square.jpg` for both the standard and the deviant trial. `checker.jpg` appears only in a comment and is not read. `number_nontarget` is 1000, so a full run is long; lower that value for a short timing check.
