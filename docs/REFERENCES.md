# References

This list separates external scientific/platform sources from SNR Lab's own
engineering decisions. A citation means the source informs a concept; it does not
mean the source validates this application.

## Audiometry and hearing measurement

1. American Speech-Language-Hearing Association. **Guidelines for Manual
   Pure-Tone Threshold Audiometry** (2005).
   <https://www.asha.org/policy/GL2005-00014/>

   Relevant to familiarization, standard frequencies, frequency order,
   10-down/5-up ascending threshold search, two responses out of three, the
   repeated 1 kHz check, environment, transducers, calibration, and masking.

2. American Speech-Language-Hearing Association. **Audiometric Symbols** (1990).
   <https://www.asha.org/policy/gl1990-00006/>

   Relevant to conventional left/right and air/bone/masking symbol distinctions.
   SNR Lab uses only the familiar red-right `O` and blue-left `X` display analogy.

3. Levitt, H. **Transformed Up-Down Methods in Psychoacoustics.** *Journal of the
   Acoustical Society of America* 49(2B), 467–477 (1971).
   <https://doi.org/10.1121/1.1912375>

   Foundational background for adaptive staircase methods. SNR Lab's exact
   clinical-style 10-down/5-up implementation and stopping rule are documented
   separately and should not be conflated with every transformed staircase in
   the paper.

## Psychometric functions and uncertainty

4. Wichmann, F. A., and Hill, N. J. **The psychometric function: II.
   Bootstrap-based confidence intervals and sampling.** *Perception &
   Psychophysics* 63, 1314–1329 (2001).
   <https://doi.org/10.3758/BF03194545>

   Relevant to bootstrap-based uncertainty for psychometric-function parameters.
   SNR Lab's 120-sample percentile bootstrap is a small MVP implementation, not a
   reproduction of the paper's complete methodology.

## Apple audio platform

5. Apple. **AVAudioEngine.**
   <https://developer.apple.com/documentation/avfaudio/avaudioengine>

   Node-based real-time audio rendering used for test stimuli and personalized
   playback.

6. Apple. **AVAudioUnitEQFilterParameters.filterType.**
   <https://developer.apple.com/documentation/avfaudio/avaudiouniteqfilterparameters/filtertype>

   EQ filter types and associated frequency/gain/bandwidth parameters.

7. Apple. **AVAudioSession.outputNumberOfChannels.**
   <https://developer.apple.com/documentation/avfaudio/avaudiosession/outputnumberofchannels>

   Current output-route channel count used by the stereo setup check.

8. Apple. **AVAudioSession.currentRoute.**
   <https://developer.apple.com/documentation/avfaudio/avaudiosession/currentroute>

   Current input/output route information.

9. Apple. **Bluetooth A2DP audio-session routing.**
   <https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetootha2dp>

   Describes A2DP as a stereo, output-only, higher-bandwidth Bluetooth profile and
   explains playback-category routing behavior.

10. Apple. **AVSpeechSynthesizer.write(_:toBufferCallback:).**
    <https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write%28_%3Atobuffercallback%3A%29>

    PCM speech-buffer generation used before local noise mixing.

11. Apple. **Speech synthesis.**
    <https://developer.apple.com/documentation/avfaudio/speech-synthesis>

    System voices and utterance rate/pitch configuration.

## Hearing safety

12. U.S. National Institute for Occupational Safety and Health. **Noise-Induced
    Hearing Loss** (updated 2024).
    <https://www.cdc.gov/niosh/noise/about/noise.html>

    Relevant to the dependence of hearing risk on acoustic level, duration, and
    repetition. Its occupational limits are not direct dBFS or consumer playback
    limits.

13. NIOSH. **Understanding Noise Exposure Limits: Occupational vs. General
    Environmental Noise** (2016).
    <https://www.cdc.gov/niosh/bulletin/2016/noise.html>

    Relevant to the 3 dB time/intensity tradeoff and the distinction between
    occupational exposure criteria and general recreational listening.

## App distribution, privacy, and health claims

14. Apple. **App Review Guidelines.**
    <https://developer.apple.com/app-store/review/guidelines/>

    Section 1.4 is relevant to physical-harm risk and health-measurement accuracy
    claims. Other sections cover privacy, completeness, metadata, and content.

15. Apple. **Manage app privacy.**
    <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>

    Privacy-policy URL and App Privacy disclosure requirements.

16. Apple. **Add a new app.**
    <https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app>

    App Store Connect app-record requirements.

17. Apple. **Choosing a Membership.**
    <https://developer.apple.com/support/compare-memberships/>

    Personal-device development versus Apple Developer Program distribution, and
    individual versus organization seller identity.

## Project content

18. FreePD music collection. <https://en.freepd.cn/music>

    Recorded source for the ten bundled demonstration tracks. The repository
    captures the source pages and CC0/public-domain designation in
    [`../SNRLab/Resources/DemoMusic/LICENSE.md`](../SNRLab/Resources/DemoMusic/LICENSE.md).

## Reading the claims correctly

- **“Based on”** means an external method informed an engineering choice.
- **“Resembles”** means the interface/procedure shares a convention.
- **“Validated”** should be used only after appropriate reference measurements and
  studies meet predefined acceptance criteria.
- **“Relative”** means meaningful only within the documented digital and setup
  context; it is not an absolute acoustic or clinical unit.
