# Validation status and limitations

## Status statement

SNR Lab is an engineering MVP. The current source has been Swift type-checked,
built with Xcode, signed for development, installed on a physical iPhone, and
observed running. A deterministic staircase exercise has also been performed
during development.

That evidence demonstrates buildability and basic execution. It does **not**
demonstrate acoustic accuracy, clinical validity, diagnostic performance,
therapeutic benefit, population reliability, or regulatory compliance.

## Evidence matrix

| Area | Present evidence | Not yet established |
| --- | --- | --- |
| Compilation | Whole-source iPhone SDK type-check; Xcode device build | CI across Xcode/iOS versions |
| Device execution | Development-signed install and launch on one iPhone | Broad hardware/OS matrix and endurance testing |
| Staircase logic | Deterministic code-level exercise; transparent trial log | Formal unit/property tests and human psychophysics validation |
| Channel routing | Stereo PCM construction and manual L/R setup checks | Acoustic channel-isolation measurements across AirPods models |
| Tone levels | Known digital equations and caps | SPL/dB HL calibration and distortion measurements |
| Speech SNR | Known digital RMS ratio | Acoustic SNR at the eardrum and standardized speech-test validity |
| Psychometric fit | Deterministic grid search and bootstrap implementation | Bias, coverage, fit rejection, normative population data |
| Compensation | Code-level independent L/R EQ and shared headroom | Perceptual benefit, output safety, peak analysis, clinical fitting validity |
| Privacy | Source audit shows local-only MVP with no upload stack | Independent security/privacy audit and release-binary traffic test |
| Accessibility | Large controls and labels are present | VoiceOver, Dynamic Type, contrast, motor and cognitive usability study |

## Primary scientific limitations

### No acoustic calibration

The app knows PCM amplitude in dBFS, not sound pressure at the eardrum. It does not
measure or lock:

- iPhone system volume;
- AirPods model/firmware-specific transfer function;
- Bluetooth codec and DSP state;
- ear-tip seal, insertion, leakage, or anatomy;
- actual noise-control mode;
- acoustic output SPL;
- reference-equivalent threshold sound pressure levels.

Therefore the vertical pure-tone scale cannot be dB HL. Comparing results is most
meaningful only under closely repeated setup conditions.

### No clinical masking or bone conduction

The non-test digital channel is silent. The app does not determine when cross-
hearing may occur and does not implement plateau masking. An optional generator
parameter is only an architectural placeholder. No bone-conduction transducer is
supported, so air-bone gaps and site-of-lesion questions cannot be assessed.

### Ambient estimate is uncalibrated

The microphone room check reports dBFS and uses a −42 dBFS heuristic. Different
microphones, routes, automatic processing, and positions can produce different
values for the same room. It cannot certify an audiometric test environment.

### Behavioral and human-factor uncertainty

Thresholds depend on comprehension, attention, motor timing, fatigue, tinnitus,
expectation, and willingness to respond. Catch trials and a repeated 1 kHz point
provide useful indicators but cannot guarantee truthful or stable responses.

### Speech materials are not standardized

The sentence banks, system voices, word scoring, and synthetic noise families are
application materials, not a standardized clinical corpus. Voice availability
and quality vary by device. Girl/Boy profiles are pitch-altered simulations.

The adaptive 72% rule, trial counts, and logistic objective have not been compared
against a reference speech-in-noise protocol. SNR values should be treated as
within-app digital estimates.

### Reliability score is heuristic

The 0–100 score and every cutoff are designed for transparent feedback, not
derived from a validation cohort. The score is not a probability that a result is
correct, and a high score does not imply clinical accuracy.

### Compensation is not a prescription

The filter uses within-ear relative shape, half gain, local smoothing, and a
user-selected cap. It does not model:

- absolute hearing threshold;
- loudness recruitment;
- uncomfortable loudness level;
- compression or frequency-dependent compression;
- real-ear insertion response;
- binaural loudness balance;
- speech audibility targets;
- device output limits or safe listening dose.

The maximum “20 dB” control is an EQ parameter, not a guaranteed acoustic gain.

## Validation roadmap

### 1. Automated software tests

Create a unit-test target and cover:

- 10-down/5-up boundaries and five-unit quantization;
- threshold completion only at the intended ascending criterion;
- presentation-cap fallback flag;
- reversal counting;
- catch and premature events never moving the staircase;
- legacy `Codable` compatibility;
- exact reliability penalties and boundary values;
- psychometric fit on known synthetic curves;
- bootstrap determinism and interval ordering;
- word-token handling in English and Spanish;
- compensation reference, smoothing, cap, missing-band and per-ear isolation;
- headroom conversion and filter-bypass behavior.

Add property tests for invariants such as:

```text
0 ≤ relative threshold ≤ 80
0 ≤ filter gain ≤ configured maximum ≤ 20
0 ≤ reliability score ≤ 100
left input never changes the right filter calculation
catch trials never contain a stimulus level
```

### 2. Digital audio verification

Render stimuli offline and measure:

- frequency error and phase continuity;
- pulse and gap durations;
- attack/release envelope;
- target-channel energy and opposite-channel digital silence;
- harmonic distortion introduced by the generator and processing graph;
- achieved speech/noise RMS ratio;
- combined EQ transfer function;
- sample peaks and true/inter-sample peaks before and after EQ;
- player synchronization and seek alignment.

### 3. Device acoustic characterization

For every supported iPhone/AirPods model and operating mode:

1. Use a suitable ear simulator/coupler and calibrated measurement chain.
2. Record output versus frequency, dBFS, system volume, channel, codec state, fit,
   battery state, firmware, and noise-control mode.
3. Measure repeatability, channel separation, harmonic distortion, and maximum
   output.
4. Define supported configurations and reject unknown configurations.
5. Create signed/versioned calibration profiles with uncertainty budgets.
6. Verify that any conversion to SPL or dB HL follows the appropriate current
   standard and reference-equivalent levels.

### 4. Test-environment validation

Compare the microphone estimator with a calibrated sound-level meter over rooms,
noise spectra, microphone routes, orientations, and device processing states.
Define frequency-specific permissible ambient noise rather than a single dBFS
number.

### 5. Human study

With ethics and professional oversight where applicable, compare the app with a
clinical reference protocol across:

- normal hearing and diverse hearing configurations;
- repeated sessions and operators;
- AirPods models and fits;
- quiet and controlled noise conditions;
- age and accessibility needs;
- left/right asymmetry;
- tinnitus and false-response behaviors.

Report bias, limits of agreement, test-retest distribution, completion time,
failure rate, sensitivity to setup, and uncertainty by frequency. Do not relabel
the scale until evidence supports the claimed quantity.

### 6. Speech validation

Use licensed/standardized materials or publish a validated corpus. Evaluate:

- list equivalence and learning effects;
- talker/voice equivalence;
- language and dialect effects;
- scorer validity;
- psychometric model fit and lapse behavior;
- bootstrap interval coverage;
- agreement with a reference speech-in-noise measure;
- minimum trials needed for stable SNR50/SNR80/SNR90.

### 7. Compensation validation

Before claiming improved fidelity or hearing benefit:

- measure the complete acoustic transfer function;
- compare filter predictions with achieved output;
- test clipping, limiting, battery, route changes, and maximum volume;
- measure preference and intelligibility using blinded level-matched comparisons;
- evaluate discomfort and adverse events;
- define safe failure behavior when measurements are incomplete or unreliable.

## App Store and health-claim review

Apple states that health-measurement apps must disclose data and methodology for
accuracy claims and that unvalidated medical measurements can be rejected. See
the [App Review Guidelines, section 1.4](https://developer.apple.com/app-store/review/guidelines/).

Before submission:

- keep “relative—not dB HL” visible throughout the product and listing;
- avoid hearing-loss severity categories, diagnosis, treatment, or guaranteed
  fidelity claims;
- provide a public privacy policy and accurate App Privacy answers;
- document the method and its limitations for App Review;
- make every URL, support path, permission description, and bundled-content
  license final;
- obtain legal/regulatory advice appropriate to intended use and storefronts.

## Definition of a validated release

A build should not be described as calibrated or clinically validated merely
because it compiles, runs, resembles an audiogram, or agrees with itself. A
validated claim needs a predefined intended use, traceable references, a tested
hardware/software configuration, an uncertainty analysis, an appropriate study,
and evidence that performance meets prospectively defined acceptance criteria.
