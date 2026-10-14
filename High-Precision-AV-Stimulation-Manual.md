# High-Precision Audio-Visual Stimulus Presentation with PTB: Hardware–Software–Algorithm Manual

> Beginner-friendly edition · Distilled from three lab records: `实验记录2024_11.docx` (Nov 2024 campaign), `操作流程.docx` (setup guide), `高刷屏幕测试/实验记录.docx` (2025 high-refresh-rate campaign).
> Goal: make the interval between "the computer says go" and "the participant really sees/hears it" **short, stable, and audio-visually aligned**.

---

## 0. The core idea in one paragraph

MEG resolves milliseconds. Before each stimulus we send a square wave (Trigger) to the sync acquisition circuit and treat its **rising edge** as "stimulus onset".

But in reality:

```mermaid
sequenceDiagram
    participant P as Stimulus program (PTB)
    participant T as Trigger Box / serial
    participant D as Display / sound card / earphone
    participant S as Participant (eye/ear)
    participant N as NI acquisition card
    P->>T: IOPort Write(255), log 'when'
    T->>N: square-wave rising edge (t0)
    P->>D: Flip frame / Start audio (scheduled at when+15ms)
    D->>S: light/sound truly arrives (t1)
    S->>N: photodiode / microphone records t1
    Note over T,N: delay = t1 - t0; must be measured and compensated
```

![Delay definition](assets/fig_timing.png)

- **Delay** = physical arrival − Trigger rising edge. Tens of ms is normal.
- **Jitter** = delay wobbling trial to trial. That is the killer. Averaging needs jitter **<1 ms**; AV alignment needs **<0.5 ms**.
- Everything in this manual exists to push jitter below 1 ms while keeping absolute delay small and compensable.

Representative results (measured):

![Jitter before vs after](assets/fig_jitter.png)

| Condition | Visual delay | Auditory delay | AV offset | Verdict |
|---|---|---|---|---|
| Starting point (Win + defaults) | 47 ms ±1 ms | 49 ms ±20 ms | — | audio unusable |
| Optimized 60 Hz (Ubuntu + AMD) | 44–69 ms ±0.1–0.4 ms | 29.2 ms ±0.1 ms | ±0.2 ms | passes, ready for experiments |
| 144 Hz high-refresh | ~19→12→8 ms ±0.2 ms | ~21 ms ±0.1 ms | ±0.1 ms | faster = smaller |
| 240 Hz (AOC / Optoma) | ~5.6 ms ±0.05 ms | — | — | full-speed B/W alternation limit |

![Higher refresh, smaller delay](assets/fig_refresh.png)

---

## 1. Hardware: what to buy and how to wire it

### 1.1 Don't confuse the two systems

```mermaid
flowchart LR
    subgraph A[Stimulation system]
        PC[Desktop PC + discrete AMD GPU]
        PROJ[Projector / high-refresh screen]
        HP[Earphone / air tube]
        TB[Trigger Box<br/>serial]
        PC --> PROJ
        PC --> HP
        PC -->|/dev/ttyUSB0| TB
    end
    subgraph B[Calibration rig - only for delay measurement]
        PD[Photodiode on white patch]
        MIC[Microphone at earphone outlet]
        NI[NI cDAQ9171<br/>10 kHz 3-channel sync]
        PD --> NI
        MIC --> NI
        TB --> NI
    end
    PROJ -.light.-> PD
    HP -.sound.-> MIC
```

![Hardware wiring overview](assets/fig_wiring_en.png)

**Real photos (from `实验记录2024_11.docx`, Fig. 1)** — left: microphone fixed at the earphone / air-tube outlet to record sound; right: photodiode fixed on the white patch of the screen to record light. Both plus the Trigger square wave go into the NI cDAQ9171 (10 kHz, 3 channels in sync):

| Microphone mounting | Photodiode mounting |
|---|---|
| ![Microphone photo](assets/photo_mic.jpg) | ![Photodiode photo](assets/photo_photodiode.jpg) |

> Photo checklist: mic capsule faces the sound outlet (move it to the adapter-box outlet when using an air tube); photodiode face sits flush on the white patch with black tape blocking stray light; tape all cables down — one wiggle = one outlier.

- **Stimulus PC**: must be a **desktop + discrete GPU**, preferably an **older AMD card** (e.g. RX 5700 XT, released ≤2020). Reason: PTB works best with open-source drivers (amdgpu/mesa); Nvidia proprietary drivers, hybrid laptop graphics and Intel iGPUs all raise sync errors.
- **Display**: a plain 60 Hz projector works; high-refresh screens/projectors (144/240 Hz) give smaller absolute delay. Keep all screens at the same resolution, otherwise PTB sync degrades.
- **Audio**: an **air tube** into the shielded room adds ~**10 ms** acoustic delay — compensate it. The sound card must be exclusively owned by PTB.
- **Trigger**: USB-to-serial to the Trigger Box. On Ubuntu it is `/dev/ttyUSB0`; add your user to the `dialout` group.
- **Calibration rig** (only connected during characterization, not every session): photodiode + microphone + NI card recording `Trigger/Sound/Light` at 10 kHz. The light sensor bandwidth is ~1.75 kHz (0.2 ms fall time) — plenty; low SNR is fixed by filtering (§5).

> Beginner traps: no laptops for real sessions; "mirrored" screen image breaks at fast B/W alternation; cheap esports screens flash randomly and produce outliers — AOC, ViewSonic and the Optoma 240 Hz projector measured stable, while some no-name/CFORCE panels did not.

---

## 2. Software: the one worry-free combo

```mermaid
flowchart TD
    U[Ubuntu 20.04.6 LTS] --> K[linux-lowlatency kernel]
    K --> M[MATLAB 2020b / Octave]
    M --> P[PTB 3.0.21 unzip + setuppsychtoolbox]
    U --> G[Full GStreamer stack]
    U --> X[XOrg + Wayland disabled<br/>XOrgConfCreator for screens]
    P --> C[PsychLinuxConfiguration<br/>Priority elevation]
```

- **Pin Ubuntu 20.04**: releases after 22.04 phase out XOrg for Wayland, which PTB (unfunded) cannot follow — lots of bugs (the famous 24.04 "click the top-right corner to restore pageflipping" bug; 25.04 dual-screen looks fine but PTB sync can still fail). 20.04 + stock open-source drivers is the stable pick.
- **Key switches**:
  - Disable Secure Boot in BIOS; `WaylandEnable=false` in `/etc/gdm3/custom.conf`; launch with plain `matlab`, never `sudo matlab`.
  - `sudo apt install linux-lowlatency`.
  - Install the full GStreamer set per the official guide (needed for video stimuli).
  - Don't `apt`-install PTB (too slow) — download the zip, unzip to a normal folder (not inside the MATLAB toolbox), `cd` there and run `SetupPsychtoolbox`, then `PsychLinuxConfiguration`.
- **GPU driver**: with AMD just use the stock open-source driver; don't chase proprietary ones. If you insist on Nvidia, `blacklist nouveau` and install the `.run` from tty with gdm3 stopped — but expect worse sync than AMD.

---

## 3. Display configuration: Single vs Multi screens, explained once

| Mode | How | Pros | Cons |
|---|---|---|---|
| Single screen | `XOrgConfCreator` merges projector + monitor into one big screen, `Screen('OpenWindow',0)` fullscreen | best sync, exact refresh | all screens must share one resolution; drawing X must be offset by half a screen; refresh is dragged down by the slowest panel |
| Multi X-Screen | each output is its own Screen (`Screen 0/1/2`) | per-screen refresh (e.g. main 60 + stim 144) | slightly worse timing, needs `ScreenToHead` to pick the sync reference |

```matlab
% Single-screen exclusive + sync source (middle numbers are found by trial; DP3 often gives 3)
Screen('Preference','ScreenToHead',0,1,3,0);
Screen('Preference','SkipSyncTests',0);   % 0 = run the sync check; only pass counts
[window, rect] = Screen('OpenWindow', 0, black);  % fullscreen, covers every other GUI
HideCursor;  % must come AFTER OpenWindow
```

- Toolchain: with no Conf file, set resolution/refresh in the desktop Display panel → generate with `XOrgConfCreator` in MATLAB → pick with `XOrgConfSelector`. If it breaks, just delete the new Conf under `/etc/X11/xorg.conf.d/` and reboot.
- Can't see the extended screen's modes? Query per screen: `xrandr --screen 2`; set rate e.g. `xrandr --screen 2 --output HDMI-2 --mode 2560x1440 --rate 144`.
- Done = `SkipSyncTests=0` passes with no `Synchronization Failure/Trouble` and no `didn't use pageflipping`. On 24.04, if pageflip is reported, click the desktop's top-right/notification area once and rerun (a confirmed GNOME bug).

---

## 4. Core algorithm: 12 PTB rules (memorize them)

> Paid for with thousands of measured trials in Nov 2024. Breaking any single rule can throw you back to ±5 ms or even ±50 ms.

1. **Desktop + discrete AMD GPU + Ubuntu + MATLAB/Octave**. No Nvidia-proprietary, no laptop iGPU, no Windows for real sessions (Windows best case ≈ 2 ms wobble, and SyncTest is a lottery).
2. **Exclusive sound card, minimal buffer**: `handle=PsychPortAudio('Open',[],1,3,sf,2,1)`. The `3` is latency class 3 (lowest-latency exclusive mode); buffer size `1` auto-selects the minimum (e.g. 14). Classes `1/2/4` were all tried — only `3` holds jitter within 1 ms; class `1` splits into two delay clusters 10 ms apart (the card's high output latency).
3. **One screen exclusively owning the GPU** (§3); remember the half-screen X offset when drawing.
4. **`ScreenToHead` + `SkipSyncTests=0`** as a pair; try parameter values until no error is reported.
5. **`OpenWindow` fullscreen**, `HideCursor` after it.
6. **Schedule presentation 15 ms after Trigger** (the core formula):
```matlab
[nwritten, when] = IOPort('Write', handle, uint8(255));
PsychPortAudio('Start', pahandle, 1, when+0.015, 0);
onset = Screen('Flip', window, when+0.015);
```
Why 15 ms? It leaves the hardware time to respond. Note frame quantization: at 60 Hz one frame is 16.67 ms, so 15 ms lands on the next frame (≈16.67 ms), 30 ms lands on 33.3 ms — that is normal.
7. **Warm up**: run the paradigm once before the real session (loads all mex files), then **don't change folders**; **discard the first trial** (the first few trials always wobble — an inherent MATLAB/PC trait).
8. **No `WaitSecs`, `GetSecs` or `now` inside the trial loop**: they suspend the MATLAB thread and fight `Flip` for the CPU. Proven by injection: 38 randomly inserted `WaitSecs(0.005)` produced exactly 38–43 extra delay outliers, matching PTB's missed-deadline count. Do all timing with `Flip`'s `when` argument; `KbCheck` may stay (compatible), `KbWait` is OK, `WaitSecs('UntilTime',…)` is "a suspended sentence" — avoid if possible.
9. **Button precision**: `KbWait` polls roughly every 5 ms; for better RT loop `KbCheck` and use `deltaSec` to bound the error; the rigorous option is routing the button signal into the NI/MEG sync acquisition.
10. **Order! Flip first, Trigger second**: `Flip`→`IOPort Write` eliminates the "one extra frame (16.67 ms)" outliers. A paper-style `Flip`-then-`Trigger` reads one frame smaller (≈6.9 ms @144 Hz) — that is "cheating"; state your convention. This manual uses the honest **Trigger-first, scheduled presentation** convention: one frame larger but comparable.
11. **Audio first, video second**: `Start` audio before `Flip`, otherwise audio jitter inherits the video wait. For AV sync see §6.
12. **Video stimuli**: `PlayMovie` (pre-decode) at each trial start, then blocking `GetMovieImage(...,1,[],2)`; draw the first frame into the back buffer before scheduling; later frames with `onset+ifi*(holdFrames-0.5)` (the −0.5 lands mid-refresh so you never straddle a boundary); no decoding inside the response window.

Minimal working template (one trial):

```matlab
% init (once)
Screen('Preference','ScreenToHead',0,1,3,0);
Screen('Preference','SkipSyncTests',0);
pahandle = PsychPortAudio('Open',[],1,3,sf,2,1);
PsychPortAudio('FillBuffer', pahandle, wave);   % with class 3, stage one frequency at a time
[win, rect] = Screen('OpenWindow', 0, black); HideCursor;
% trial loop (no WaitSecs/GetSecs)
Screen('FillRect', win, black); Screen('DrawTexture', win, tex);
[nwritten, when] = IOPort('Write', h, uint8(cond));
PsychPortAudio('Start', pahandle, 1, when+0.015, 0);
onset = Screen('Flip', win, when+0.015);   % ≈ when+16.67ms at 60Hz
onset = Screen('Flip', win, onset + ifi*(holdFrames-0.5));  % hold duration, no WaitSecs
```

---

## 5. Measuring and validating delay: learn to characterize your own rig

```mermaid
flowchart TD
    R[NI 3-channel sync @10kHz] --> F{Filter}
    F -->|audio| T1[Threshold rising edge]
    F -->|light| T2[Notch 48-52Hz + lowpass<br/>then threshold/peak]
    T1 --> D[delay = t_stim - t_trigger]
    T2 --> D
    D --> S[Mean±SD + drop first trial + count outliers]
```

- **Record what**: `visual_N.txt` / `audio_N.txt` / `visual_audio_N.txt` with 3 columns Trigger/Sound/Light.
- **How to find the edge**: audio by direct threshold; light after a `[48,52] Hz notch + 60/70/80 Hz lowpass` (2nd-order Butterworth), then threshold/peak. Just switching the edge criterion once shrank variance from 0.49 ms to 0.2 ms — when variance is big, fix the detector before blaming PTB.
- **What to report**:
  - `Mean±SD` (e.g. `44.805±0.165 ms`), `Gaps` (Trigger intervals: `33.36±0.07 ms` @60 Hz, `13.89±0.08 ms` @144 Hz, `8.34±0.05 ms` @240 Hz).
  - Outlier fraction (e.g. `35/1309 = 2.67%`), and whether PTB's `missed deadline x/y` matches the outlier count.
  - Standard 5-step validation: ① full-speed Flip for refresh + Trigger stability → ② random ISI + timed Flip for vision → ③ random ISI + timed audio → ④ all three + button load for sync → ⑤ long run (1000–8000 trials).
- **The big first-trial wobble is normal**: the first 5–10 trials run long; declare "first trial dropped" in your statistics.

---

## 6. AV sync: aligning light and sound within 0.5 ms

The hard part: vision is frame-quantized (16.67 ms steps at 60 Hz) while audio can be scheduled freely; and an air tube makes audio **slower** than vision — the toughest case.

```mermaid
flowchart TD
    A[Free run once, no compensation<br/>measure natural light-sound gap D] --> B{Who is faster?}
    B -->|audio faster - typical w/o tube| C[Fix vision with Flip first<br/>then Start audio at visual time minus offset]
    B -->|audio slower - air tube ~+10ms| D[Push vision back N frames via PredictVisualOnset<br/>so vision is slower, then delay audio to catch up]
    C --> E[Tune audioExtraDelay in ±1ms steps<br/>until light-sound gap ≈ 0 ±0.2ms]
    D --> E
```

Field-tested code (high-refresh / air-tube version):

```matlab
t1 = GetSecs;   % anchor only, NOT called at high rate inside the loop
tonset = PredictVisualOnsetForTime(window, t1);
audioWhen = tonset + ifi*5.5 + p.audioExtraDelay;  % +5.5 frames guarantees vision is later
PsychPortAudio('Start', pahandle, 1, audioWhen, 0);
visualOnset = Screen('Flip', window, tonset + ifi*0.5);
[nwritten, triggerWhen] = IOPort('Write', portHandle, uint8(stimN));
```

- The `0.5` in `ifi*5.5` keeps you off the refresh boundary so you never slip an extra frame; tune `audioExtraDelay` in ±1–2 ms steps toward `sound − light ≈ 0 ± 0.2 ms` (best lab result: `−0.02 ± 0.08 ms`).
- If at 144 Hz you are stuck ~8 ms (one frame) off no matter what, the audio wait has outrun the Flip window — drop to 60 Hz (16.67 ms wide frames forgive a lot) and tune there. That is the trade-off: high-refresh = small delay but fiddly sync; 60 Hz = easy sync.
- After syncing, re-validate long runs: vision peak-to-peak <1 ms, audio ±0.1 ms, AV peak-to-peak <1 ms.

---

## 7. Troubleshooting table (check here before reinstalling anything)

| Symptom | Most likely cause | Fix |
|---|---|---|
| `Synchronization Failure / Trouble`, mass `missed deadline` | wrong GPU/driver/screen wiring; Nvidia proprietary / iGPU / laptop | switch to discrete AMD; rerun `XOrgConfCreator/Selector`; try `ScreenToHead` variants; single-screen mode; restart MATLAB; on 24.04 click the top-right notification area |
| `didn't use pageflipping` | GNOME compositor won't yield fullscreen | click top-right + notification once; try KDE; fall back to 20.04; disable Wayland |
| Two delay clusters (~10 ms apart) | `latencyclass≠3` / buffer too big / card busy | `Open(...,3,...,1)` + exclusive + buffer=1; kill other audio apps; max-out power plan |
| First trials huge, density jump mid-run | MATLAB warm-up + first-frame penalty + resolution changed without restart | warm-up run, drop first trial, restart MATLAB/PC after display changes |
| Jitter as soon as `WaitSecs` is added | thread fight with `Flip` (iron rule) | replace all waits with `Flip(when)`; keep `KbCheck`, move `GetSecs/now` out of the loop |
| Constant one-frame AV gap (16.6/6.9/8.3 ms) | Flip-before vs after Trigger convention / audio compensation out of window | unify convention; retune `audioExtraDelay`/frame count per §6; tune at 60 Hz if needed |
| Projector 127 ms ±8 ms, high-refresh won't lock | old machine + Nvidia + too-ambitious refresh | AMD-era card + 20.04; characterize projector at its native 60 Hz; use validated AOC/ViewSonic/Optoma 240 Hz for high-refresh |
| `libGL fail to open nouveau/swrast` | driver symlink lost | `ln -s /usr/lib/x86_64-linux-gnu/dri/nouveau_dri.so /usr/lib/dri/` plus the MATLAB `libstdc++.so.6` symlink |
| Serial port missing | user not in `dialout` | locate with `ls /dev/ttyUSB*` + `dmesg\|grep ttyUSB`, `usermod -aG dialout <user>`, reboot |

---

## 8. Standard operating flow: from power-on to experiment

```mermaid
flowchart TD
    S1[Boot Ubuntu-XOrg<br/>confirm res/refresh with xrandr] --> S2[Click top-right once - anti-pageflip bug]
    S2 --> S3[Open MATLAB, cd to PTB folder, warm-up run]
    S3 --> S4[Attach photodiode/mic, start NI]
    S4 --> S5[100-trial short calibration: Mean±SD + miss count]
    S5 -->|out of spec| T[Troubleshoot per §7]
    T --> S5
    S5 -->|in spec| S6[1000+ formal trials, drop first, archive]
    S6 --> S7[Offline filter + edge stats, write report]
```

Repeat the whole flow whenever you change screens, cables, refresh rates or PCs. Name captures `visual/audio/visual_audio_<N>.txt` plus `gaps_<N>.txt` (PTB-readback `when/onset`) for traceability.

---

## Appendix A. Parameter cheat card

- Audio: `PsychPortAudio('Open',[],1,3,sf,2,1)`, `FillBuffer` before Trigger, `Start(...,when+0.015,0)` (`waitForStart=0` schedules instead of blocking).
- Vision: `Flip(window, when+0.015)`; hold with `Flip(window, onset+ifi*(hold-0.5))`.
- Sync: `PredictVisualOnsetForTime` + `ifi*5.5` + fine `audioExtraDelay`.
- Statistics: drop first trial; targets: vision ±0.4 ms / audio ±0.1 ms / AV ±0.25 ms; 240 Hz full-speed reaches ±0.05 ms.
- Yardsticks to keep in mind: air tube +10 ms; one frame = 16.67 ms @60 Hz, 6.94 ms @144 Hz, 4.17 ms @240 Hz — compensate with this ruler in hand.

> Closing line: **good hardware (AMD + Ubuntu 20.04) × correct code (15 ms scheduling + no WaitSecs + audio-before-video + Trigger-after-Flip) × diligent calibration (NI 3-channel + filtering + long runs) = high temporal precision.** May your first run be stable.
