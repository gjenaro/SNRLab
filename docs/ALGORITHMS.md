# Algorithms and implementation constants

This document is a code-level specification of the current MVP. Values here are
descriptive, not clinical recommendations. The source of truth remains the Swift
implementation.

## Bilateral pure-tone workflow

### Test targets

Each ear uses this sequence:

```text
1000 → 2000 → 3000 → 4000 → 6000 → 8000
     → repeat 1000 → 500 → 250 Hz
```

The application currently tests the left ear first and then the right ear. It
repeats 1 kHz in both ears even though some conventional procedures omit the
second-ear retest. This deliberate extra measurement supplies a symmetric
within-session quality check.

### Setup gates

Testing cannot begin until all are true:

- iOS reports an AirPods-named output route;
- the route reports at least two output channels;
- the listener confirms both earbuds are connected and seated;
- Transparency mode is reported off by the listener;
- the listener agrees to preserve noise-control mode and system volume;
- the listener confirms a quiet room;
- audible left-only and right-only channel checks are confirmed.

An optional four-second microphone estimate records the rolling low-percentile
level in dBFS. Values above −42 dBFS receive a quality warning. This cutoff is an
uncalibrated engineering heuristic.

### Practice

Each ear receives a 1 kHz practice tone at −27 dBFS. Practice uses the same pulsed
generator and channel routing but does not enter the threshold record.

### Starting level

The staircase stores levels in five-unit increments from 0 to 80.

For the first frequency of an ear:

$$
r_0=35-10=25.
$$

For subsequent frequencies, the starting point is ten units below the most
recent non-retest threshold. The repeated 1 kHz starts ten units below the first
1 kHz threshold. Every result is rounded to a five-unit grid and clamped to
0…80.

### Presentation state

```mermaid
stateDiagram-v2
    [*] --> RouteCheck
    RouteCheck --> Paused: route invalid
    Paused --> RouteCheck: reconnect
    RouteCheck --> Waiting: route valid
    Waiting --> Premature: tap before onset
    Waiting --> CatchWindow: catch selected
    Waiting --> ToneWindow: real trial
    Premature --> Next
    CatchWindow --> CatchHeard: tap
    CatchWindow --> CatchMissed: timeout
    ToneWindow --> Heard: tap
    ToneWindow --> Missed: timeout
    CatchHeard --> Next
    CatchMissed --> Next
    Heard --> Evaluate
    Missed --> Evaluate
    Evaluate --> ThresholdComplete: criterion or cap
    Evaluate --> Next: continue staircase
    Next --> RouteCheck
```

The pre-stimulus delay is uniformly random in 0.85…2.15 seconds. After onset, the
response window lasts 1.55 seconds. A normal tone lasts approximately one second,
so the remaining time permits a post-stimulus response.

### Catch scheduling

No catch is inserted before seven real, non-premature presentations in an ear.
After that:

- if at least 14 trials have occurred since the last catch, a catch is forced;
- if 8–13 trials have occurred, there is a 25% chance of a catch;
- otherwise, the next trial is real.

Catch trials do not change the staircase level. Premature taps are logged and the
trial is restarted without changing level.

### Staircase update

```text
if heard:
    nextLevel = max(0, currentLevel - 10)
else:
    nextLevel = min(80, currentLevel + 5)
```

Direction is derived by comparing the current presentation level with the prior
presented level. A reversal is counted when movement changes between ascending
and descending.

### Threshold criterion

For every level that has appeared on ascending trials, define:

$$
n_l=\text{ascending presentations at level }l,
\qquad h_l=\text{heard ascending presentations at }l.
$$

A level qualifies when

$$
h_l\ge2 \quad\text{and}\quad \frac{h_l}{n_l}\ge0.5.
$$

The result is the lowest qualifying level. At the zero-unit floor, two heard
responses also qualify even if direction classification is not ascending.

After 16 real presentations without a qualifying level, the algorithm saves the
lowest initial/ascending level with a heard fraction of at least 0.5, or the
current level if none exists. The result is marked `metAscendingCriterion=false`.

### Frequency progression

The next frequency is not started until the current staircase returns a result.
After the final 250 Hz target, the app compares the two 1 kHz thresholds. A
difference greater than five relative units prompts the listener to repeat that
ear. Accepting the ear continues to the other side or saves the bilateral test.

## Stored pure-tone observations

Every `PureToneTrial` stores:

- UUID;
- frequency;
- ear;
- optional relative stimulus level (`nil` for catch/premature events);
- heard/not heard;
- initial, ascending, descending, unchanged, or catch direction;
- optional response time;
- catch flag;
- premature-response flag;
- timestamp.

Every `PureToneThresholdResult` adds the final relative threshold, reversal count,
retest flag, ascending-criterion flag, and threshold timestamp.

## Quality metrics

### False-positive rate

$$
\mathrm{FPR}=\frac{\text{heard catch trials}}{\text{all catch trials}}.
$$

When no catch trial exists, the displayed rate is zero; absence of catches should
not be interpreted as proof of reliability.

### Reliability score

The score begins at 100 and applies these penalties:

| Condition | Penalty |
| --- | --- |
| Catch false-positive rate $f$ | $\min(45,100f)$ |
| $p$ premature taps | $\min(20,4p)$ |
| Mean 1 kHz repeat difference $d>5$ | $\min(25,2.5(d-5))$ |
| $u$ thresholds missing ascending criterion | $\min(20,5u)$ |
| Ambient estimate above −42 dBFS | 10 |

The final value is clamped to 0…100.

The test is flagged as reduced reliability if any is true:

- score below 75;
- false-positive rate above 20%;
- at least three premature taps;
- either ear's 1 kHz difference exceeds five relative units;
- any threshold used the presentation-cap fallback.

These constants have not been clinically validated. They are transparent quality
signals intended to support retesting, not formal confidence probabilities.

## Audiogram rendering

The eight standard display frequencies are mapped to

$$x=\log_2(f/250).$$

The chart plots $-r$ on a −80…0 y-domain. A left/right difference of 15 or more
relative units adds an orange vertical highlight. The 15-unit rule is a visual
attention threshold only; no cause or medical category is inferred.

## Speech-in-noise test

### Trial loop

- 14 trials.
- Initial digital SNR: +6 dB.
- Noise family selected before trial 1 and then locked.
- English or Spanish sentence chosen by trial index from a built-in bank.
- Listener hears one generated sentence and types the perceived words.
- Score at least 0.72: next SNR is 2 dB lower/harder.
- Score below 0.72: next SNR is 2 dB higher/easier.
- SNR is clamped to −10…+18 dB.

The 72% rule and 2 dB step are MVP heuristics, not a standardized speech-in-noise
protocol.

### Word scoring

Text is folded case-insensitively and diacritic-insensitively, split on non-
alphanumeric characters, and compared as a multiset. For each reference word,
one matching response token is consumed. Word order and edit distance are not
considered.

$$
\mathrm{score}=\frac{\text{matched reference tokens}}
{\text{reference tokens}}.
$$

### Speech/noise amplitude

Generated speech is normalized toward active RMS 0.12, subject to 0.90 peak
headroom. Noise is scaled using

$$R_n=R_s/10^{S/20},$$

where $S$ is target digital SNR in dB. Final samples are clipped to ±0.95 as a
last software bound.

### Sigmoid fit

The grid search minimizes

$$
E(\theta,k)=\sum_i\left[
\frac{1}{1+e^{-(s_i-\theta)/k}}-y_i
\right]^2.
$$

Search domains are $\theta\in[-10,20]$ and $k\in[0.5,10]$, each in 0.25 dB
increments. SNR50 is $\theta$; SNR80 and SNR90 are analytic inversions of the
fitted logistic curve.

### Bootstrap intervals

With at least 12 points, 120 deterministic pseudo-random bootstrap samples are
drawn with replacement. Each is refit and the nearest 2.5% and 97.5% order
statistics form the displayed interval. The seeded generator makes results
repeatable for a fixed point count and sequence.

## Volume sensitivity

The test presents six clean-speech digital targets in this order:

```text
−42, −36, −30, −24, −18, −12 dBFS
```

Each sentence is scored with the same token algorithm. The resulting curve is a
within-device recognition-versus-digital-level display. It is not an acoustic
loudness-growth or speech-audiometry measurement.

## Noise profiles

Each noise family runs eight trials beginning at +6 dB digital SNR. The same
72%/±2 dB adaptive rule applies, bounded to −10…+18 dB. The saved summary is the
two-parameter sigmoid's SNR90 estimate.

Eight trials are too few for a strong psychometric inference in many conditions;
the module is exploratory and explicitly identifies its noises as synthetic.

## Live SNR

Constants:

| Item | Value |
| --- | --- |
| Input tap | 2048 frames |
| Recent level window | 120 buffers |
| Minimum data before publish | 8 buffers |
| Publish interval | >160 ms |
| Noise statistic | 20th percentile |
| Signal statistic | 82nd percentile |
| Display clamp | −10…40 dB |
| RMS floor before log | $10^{-8}$ |

The estimator records at most 180 display-history points.

## Personalized compensation

### Inputs and guards

- Only a saved `BilateralPureToneTest` is used.
- At least four non-retest thresholds must exist for each ear.
- Speech-in-noise values never enter the EQ calculation.
- User maximum is clamped to 0…20 dB.

### Per-ear gain calculation

For each ear, sort available thresholds and choose the element at index
`count / 4` as the reference. For every target frequency, use the closest measured
frequency and calculate nonnegative half gain:

```text
deficit = max(0, threshold - reference)
rawGain = min(maximumBoost, 0.5 * deficit)
```

Smooth the vector with center/neighbor weights of 0.60/0.20/0.20. Edge weights
are divided by their available sum. Clamp the result again to 0…maximum.

### Filter configuration

| Band | Center | Type |
| --- | ---: | --- |
| 1 | 250 Hz | Low shelf |
| 2 | 500 Hz | Parametric |
| 3 | 1 kHz | Parametric |
| 4 | 2 kHz | Parametric |
| 5 | 3 kHz | Parametric |
| 6 | 4 kHz | Parametric |
| 7 | 6 kHz | Parametric |
| 8 | 8 kHz | High shelf |

All filters use 0.80-octave bandwidth where the filter type uses bandwidth. A
band is bypassed when its absolute gain is below 0.05 dB.

### Playback/headroom behavior

The stereo file is split into temporary mono float32 CAFs. Each side passes
through its own player, EQ, and hard panner. A shared mixer attenuates both modes
by `largestBoost + 1 dB`. Switching Original/Compensated toggles EQ bypass without
changing playback position.

The maximum control limits the digital filter parameter; it does not state the
acoustic gain at the ear and must not be described as prescribed amplification.
