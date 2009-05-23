[speex]
; CBR encoding quality [0..10]
; used only when vbr = false
quality => 8 

; codec complexity [0..10]
; tradeoff between cpu/quality
complexity => 1 

; perceptual enhancement [true / false]
; improves clarity of decoded speech
enhancement => false

; voice activity detection [true / false]
; reduces bitrate when no voice detected, used only for CBR
; (implicit in VBR/ABR)
vad => false

; variable bit rate [true / false]
; uses bit rate proportionate to voice complexity
vbr => false

; available bit rate [bps, 0 = off]
; encoding quality modulated to match this target bit rate
; not recommended with dtx or pp_vad - may cause bandwidth spikes
abr => 0

; VBR encoding quality [0-10]
; floating-point values allowed
vbr_quality => 4

; discontinuous transmission [true / false]
; stops transmitting completely when silence is detected
; pp_vad is far more effective but more CPU intensive
dtx => false

; preprocessor configuration
; these options only affect Speex v1.1.8 or newer

; enable preprocessor [true / false]
; allows dsp functionality below but incurs CPU overhead
preprocess => false

; preproc voice activity detection [true / false]
; more advanced equivalent of DTX, based on voice frequencies
pp_vad => false

; preproc automatic gain control [true / false]
pp_agc => false
pp_agc_level => 8000

; preproc denoiser [true / false]
pp_denoise => false

; preproc dereverb [true / false]
pp_dereverb => false
pp_dereverb_decay => 0.4
pp_dereverb_level => 0.3


[plc]
; for all codecs which do not support native PLC
; this determines whether to perform generic PLC
; there is a minor performance penalty for this
genericplc => true
