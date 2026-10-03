⍝ LEGACY experiment, not the production runtime. Production arithmetic is j/biencoder.ijs and r/biencoder.R.
⍝ TinyAPL Complex Double cannot hold Goldilocks p = 18446744069414584321.
⍝ Mini SUBLEQ bi-encoder. NOT softmax attention. NOT a trained model.
⍝ Query tower: Q ← A +/∙× Wq. Key tower: K ← (⍉B) +/∙× Wk.
⍝ Late interaction calls library SubleqPipeline on each (Q row, K row):
⍝   diff ← K−Q, pred ← diff≤0, then predicted dot ← +/ pred×Q×K.
⍝ Unmasked head is Q +/∙× ⍉K. With the fixed permutation weights
⍝ (Wq +/∙× ⍉Wk = I) that head equals A +/∙× B. The routed head is a
⍝ sparse approximation; compare it to the reference matmul and record error.
⍝ Full Goldilocks p is not an exact TinyAPL scalar. This file uses ordinary
⍝ small integers plus GSafeP=65537 on the routed sum. Python is authoritative
⍝ for p = 2^64−2^32+1.
LcgStep←{2147483647|48271×⍵}
LcgDraw←{n←⍺⋄seed←0⊇⍵⋄mod←1⊇⍵⋄buf←⟨⟩⋄i←0⋄{seed↩LcgStep seed⋄buf↩buf⍪mod|seed⋄i↩i+1⋄0}⍣{i≥n}0⋄⟨buf⋄seed⟩}
RoutedDot←{st←⍺ SubleqPipeline ⍵⋄pred←⊃2⊇st⋄+/(pred×⍺×⍵)}
RouteAgg←{0⊇⍺ SubleqPipeline ⍵}
RoutePred←{st←⍺ SubleqPipeline ⍵⋄⊃2⊇st}
PredictRows←{qq←↓⍺⋄kk←↓⍵⋄↑{q←⍵⋄{q RoutedDot ⍵}¨kk}¨qq}
AggRows←{qq←↓⍺⋄kk←↓⍵⋄↑{q←⍵⋄{q RouteAgg ⍵}¨kk}¨qq}
PredFlat←{qq←↓⍺⋄kk←↓⍵⋄∊{q←⍵⋄∊{q RoutePred ⍵}¨kk}¨qq}
GSafeRoutedDot←{st←⍺ SubleqPipeline ⍵⋄pred←⊃2⊇st⋄GSafeReduce pred×⍺×⍵}
GSafePredict←{qq←↓⍺⋄kk←↓⍵⋄↑{q←⍵⋄{q GSafeRoutedDot ⍵}¨kk}¨qq}
