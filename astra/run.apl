⍝ Astra APL driver. Runs the registry, the seeded bi-encoder, and the DAG seal.
⍝ AGPL-3.0 only.

∇ Z←A ZAllEq B;VA;VB;I;N
 VA←,A
 VB←,B
 N←⍴VA
 Z←1
 I←1
LOOP:→(I>N)/0
 →((ZDec ⊃VA[I])≡ZDec ⊃VB[I])/NX
 Z←0
 →0
NX:I←I+1
 →LOOP
∇

⎕PW←400
⎕←'ASTRA_V1'
⎕←'INTERPRETER'
⎕←'GNU APL'
ST←ZSelfTest
⎕←'ZINT_SELFTEST'
⎕←ST
ABC←⎕UCS ZShaRaw ZBytes 'abc'
⎕←'SHA512_ABC'
⎕←ABC
EMP←⎕UCS ZShaRaw ⍬
⎕←'SHA512_EMPTY'
⎕←EMP
⎕←'NATIVE_2_63'
⎕←⍕2*63
⎕←'ZINT_2_64'
⎕←ZDec ZPow2 64
⎕←'ZINT_P'
PP←ZPowP
⎕←ZDec PP
R←ZRunSeeded
A←⊃R[1]
B←⊃R[2]
Q←⊃R[3]
K←⊃R[4]
EX←⊃R[5]
REF←⊃R[6]
PR←⊃R[7]
PM←⊃R[8]
SE←⊃R[9]
SM←⊃R[10]
⎕←'A'
ZShowMat A
⎕←'B'
ZShowMat B
⎕←'Q'
ZShowMat Q
⎕←'KTOWER'
ZShowMat K
⎕←'EXACT_HEAD'
ZShowMat EX
⎕←'REFERENCE'
ZShowMat REF
⎕←'PREDICTED'
ZShowMat PR
⎕←'EXACT_EQUALS_REFERENCE'
⎕←EX ZAllEq REF
⎕←'MUTATED_PREDICTED'
ZShowMat PM
WANT←'e6b4a8fda2cde450bd3d9c2b14932136b2894e2b78a1d6c91c52681ec06f3bd7f13e660a655ca84171ccb77584cc0729792c2123ab5b4b758e74576323756f6e'
⎕←'SEAL'
⎕←SE
⎕←'SEAL_MATCH'
SMATCH←SE≡WANT
⎕←SMATCH
⎕←'MUTATED_SEAL'
⎕←SM
⎕←'MUTATED_DIFFERS'
⎕←SE≢SM
ResetAgents
Caps←(⊂'stats'),⊂'mean'
P←Profile (⊂'mean'),(⊂Caps),(⊂'mean average'),(⊂,1),⊂1
I1←Register (⊂P),⊂'MeanAgent'
Caps←(⊂'stats'),⊂'median'
P←Profile (⊂'median'),(⊂Caps),(⊂'median middle'),(⊂,1),⊂1
I2←Register (⊂P),⊂'MedianAgent'
Caps←(⊂'stats'),(⊂'trimmed'),⊂'robust'
P←Profile (⊂'trimmed'),(⊂Caps),(⊂'trimmed robust'),(⊂,2),⊂1
I3←Register (⊂P),⊂'TrimmedAgent'
Caps←(⊂'stats'),⊂'midrange'
P←Profile (⊂'midrange'),(⊂Caps),(⊂'midrange range'),(⊂,1),⊂1
I4←Register (⊂P),⊂'MidrangeAgent'
Caps←(⊂'stats'),(⊂'winsor'),⊂'robust'
P←Profile (⊂'winsor'),(⊂Caps),(⊂'winsor robust'),(⊂,2),⊂1
I5←Register (⊂P),⊂'WinsorAgent'
Caps←(⊂'stats'),⊂'consensus'
P←Profile (⊂'consensus'),(⊂Caps),(⊂'consensus vote'),(⊂,1),⊂1
I6←Register (⊂P),⊂'ConsensusAgent'
⎕←'REGISTRY_INDEX'
⎕←I1,I2,I3,I4,I5,I6
Req←(⊂'robust mean estimate'),(⊂⊂'stats'),(⊂⊂'robust'),(⊂2),(⊂5),⊂⍬
Dec←AgentProfiles Route Req
⎕←'ROUTE_IDS'
⎕←⊃Dec[1]
⎕←'ROUTE_WEIGHTS'
⎕←⊃Dec[2]
⎕←'ROUTE_SCORES'
⎕←⊃Dec[3]
⎕←'ROUTE_COST'
⎕←⊃Dec[4]
Cfg←(⊂'robust mean estimate'),(⊂3 8 1 9 2 7 4),(⊂⊂'stats'),(⊂⊂'robust'),(⊂2),(⊂6),⊂2
Mix←Mixture Cfg
⎕←'MIX_ANSWER'
⎕←⊃Mix[1]
⎕←'MIX_SPENT'
⎕←⊃Mix[5]
⎕←'MIX_SUCCESS'
⎕←⊃Mix[6]
⎕←'MIX_FAILURES'
⎕←⊃Mix[4]
⎕←'ASTRA_DONE'
CODE←1-SMATCH
⍎')OFF ',⍕CODE
