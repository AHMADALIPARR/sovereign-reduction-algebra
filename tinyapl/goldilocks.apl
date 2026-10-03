⍝ Auto-synced excerpt from library.apl — execute via demo_run.apl / pipeline flatten

⍝ Sovereign Reduction Algebra — TinyAPL primitives
⍝ File-mode note: Capitals name functions; locals must be lowercase.
⍝ Goldilocks: full p via Python reference. TinyAPL uses exact GSafeP=2^26-1.
gSafeP←65537
GSafeAdd←{gSafeP|⍺+⍵}
GSafeSub←{gSafeP|⍺-⍵}
GSafeMul←{gSafeP|⍺×⍵}
GSafeReduce←{gSafeP|+/⍵}
GSafeScan←{gSafeP|¨ScanSum ⍵}
GSafeDot←{gSafeP|+/⍺×⍵}
GSafePoly3←{x←⍵⋄c0←0⊇⍺⋄c1←1⊇⍺⋄c2←2⊇⍺⋄(((c2 GSafeMul x)GSafeAdd c1)GSafeMul x)GSafeAdd c0}
⍝ Crypto stubs — authoritative commit/seal/verify live in Python reference.
