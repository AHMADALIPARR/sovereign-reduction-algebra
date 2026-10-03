⍝ Astra APL: arbitrary-precision integers as base-10^9 limbs.
⍝ Limb vectors are the type of the arithmetic, including matrix multiply.
⍝ GNU APL signed integers become IEEE floats past about 2^63. This code
⍝ never uses that path. AGPL-3.0 only, same as the repository.
⍝
⍝ A zint is a simple integer vector: sign (¯1, 0, or 1) then little-endian
⍝ limbs in 0..ZBASE-1. Zero is ,0. Monadic ⊃ discloses, so the sign is ↑.

ZBASE←1000000000
ZPOW62←2*62

∇ ZAssertInt P;S
 S←⍕P
 →(0=∨/S∊'Ee.')/0
 ⎕←'FLOAT_DRIFT'
 ⎕←S
 ⎕ES 'FLOAT_DRIFT'
∇

∇ Z←ZIntFromDigits S;I;D
 Z←0
 I←1
 D←'0123456789'
LOOP:→(I>⍴S)/0
 →(~S[I]∊D)/BAD
 Z←(10×Z)+¯1+D⍳S[I]
 I←I+1
 →LOOP
BAD:⎕←'DIGIT_DRIFT'
 ⎕ES 'DIGIT_DRIFT'
∇

∇ Z←ZLimbsFromScalar P;S;L;W
 ZAssertInt P
 →(P=0)/ZERO
 S←(⍕P)~' '
 L←⍬
LOOP:→((⍴S)>9)/PEEL
 L←L,ZIntFromDigits S
 Z←L
 →0
PEEL:W←(¯9)↑S
 S←(¯9)↓S
 L←L,ZIntFromDigits W
 →LOOP
ZERO:Z←,0
∇

∇ Z←ZFromInt N;S
 ZAssertInt N
 S←1
 →(N≥0)/POS
 S←¯1
 N←-N
POS:→(N=0)/ZERO
 →(N<ZBASE)/ONE
 Z←S,ZLimbsFromScalar N
 →0
ONE:Z←S,N
 →0
ZERO:Z←,0
∇

∇ Z←ZPack X;S;L;N
 S←↑X
 L←1↓X
 N←⍴L
LOOP:→(N≤0)/ZERO
 →(L[N]≠0)/DONE
 N←N-1
 →LOOP
DONE:Z←S,N↑L
 →0
ZERO:Z←,0
∇

∇ Z←ZSplitBase P;POW;Q;R
 ⍝ Exact integer division of a signed-64 scalar by ZBASE.
 ZAssertInt P
 →(P≥0)/GO
 ⎕←'NEG_SPLIT'
 ⎕ES 'NEG_SPLIT'
GO:POW←ZPOW62
 Q←0
 R←0
LOOP:→(POW=0)/DONE
 R←2×R
 →(P<POW)/NOB
 P←P-POW
 R←R+1
NOB:→(R<ZBASE)/NQ
 R←R-ZBASE
 Q←(2×Q)+1
 →NX
NQ:Q←2×Q
NX:POW←⌊POW÷2
 →LOOP
DONE:→(P=0)/OK
 ⎕←'SPLIT_LEFTOVER'
 ⎕←P
 ⎕ES 'SPLIT_LEFTOVER'
OK:Z←R,Q
∇

∇ Z←ZNeg A
 Z←A
 →((↑Z)=0)/0
 Z[1]←-Z[1]
∇

∇ Z←ZAbs A
 Z←A
 →((↑Z)≠¯1)/0
 Z[1]←1
∇

∇ Z←A ZCmpAbs B;LA;LB;I
 LA←1↓A
 LB←1↓B
 →((⍴LA)≠⍴LB)/LD
 Z←0
 I←⍴LA
LOOP:→(I<1)/0
 →(LA[I]=LB[I])/NX
 →(LA[I]>LB[I])/GT
 Z←¯1
 →0
GT:Z←1
 →0
NX:I←I-1
 →LOOP
LD:→((⍴LA)>⍴LB)/GT
 Z←¯1
∇

∇ Z←A ZCmp B;SA;SB;C
 SA←↑A
 SB←↑B
 →(SA≠SB)/SD
 →(SA=0)/EQ
 C←A ZCmpAbs B
 Z←SA×C
 →0
SD:→(SA>SB)/GT
 Z←¯1
 →0
GT:Z←1
 →0
EQ:Z←0
∇

∇ Z←A ZAddAbs B;LA;LB;N;ACC;I;P;RQ;C;T
 LA←1↓ZAbs A
 LB←1↓ZAbs B
 N←(⍴LA)⌈⍴LB
 ACC←N⍴0
 →((⍴LA)=0)/ZC
 ACC[⍳⍴LA]←LA
ZC:C←0
 I←1
LOOP:→(I>N)/FIN
 P←ACC[I]+C
 →(I>⍴LB)/NC
 P←P+LB[I]
NC:RQ←ZSplitBase P
 ACC[I]←RQ[1]
 C←RQ[2]
 I←I+1
 →LOOP
FIN:→(C=0)/PACK
 ACC←ACC,C
PACK:Z←ZPack 1,ACC
∇

∇ Z←A ZSubAbs B;LA;LB;N;ACC;I;T;P;Borr
 ⍝ |A|-|B| with |A|≥|B|.
 LA←1↓ZAbs A
 LB←1↓ZAbs B
 N←⍴LA
 ACC←LA
 I←1
 Borr←0
LOOP:→(I>N)/FIN
 T←0
 →(I>⍴LB)/NT
 T←LB[I]
NT:P←(ACC[I]-T)-Borr
 →(P≥0)/OK
 P←P+ZBASE
 Borr←1
 →ST
OK:Borr←0
ST:ACC[I]←P
 I←I+1
 →LOOP
FIN:→(Borr=0)/PACK
 ⎕←'BORROW'
 ⎕ES 'BORROW'
PACK:Z←ZPack 1,ACC
∇

∇ Z←A ZAdd B;SA;SB;C
 SA←↑A
 SB←↑B
 →(SA=0)/RETB
 →(SB=0)/RETA
 →(SA≠SB)/DIF
 Z←A ZAddAbs B
 →(SA=1)/0
 Z←ZNeg Z
 →0
DIF:C←A ZCmpAbs B
 →(C=0)/ZERO
 →(C=¯1)/BL
 Z←A ZSubAbs B
 →(SA=1)/0
 Z←ZNeg Z
 →0
BL:Z←B ZSubAbs A
 →(SB=1)/0
 Z←ZNeg Z
 →0
ZERO:Z←,0
 →0
RETB:Z←B
 →0
RETA:Z←A
∇

∇ Z←A ZSub B
 Z←A ZAdd ZNeg B
∇

∇ Z←A ZMul B;SA;SB;LA;LB;NA;NB;ACC;I;J;IDX;P;RQ;C;K
 SA←↑A
 SB←↑B
 →((SA=0)∨SB=0)/ZERO
 LA←1↓A
 LB←1↓B
 NA←⍴LA
 NB←⍴LB
 ACC←(NA+NB)⍴0
 I←1
ILO:→(I>NA)/PACK
 J←1
JLO:→(J>NB)/JN
 IDX←I+J-1
 P←ACC[IDX]+LA[I]×LB[J]
 RQ←ZSplitBase P
 ACC[IDX]←RQ[1]
 C←RQ[2]
 K←IDX+1
CLO:→(C=0)/JN2
 →(K≤⍴ACC)/IN
 ACC←ACC,0
IN:P←ACC[K]+C
 RQ←ZSplitBase P
 ACC[K]←RQ[1]
 C←RQ[2]
 K←K+1
 →CLO
JN2:J←J+1
 →JLO
JN:I←I+1
 →ILO
PACK:Z←ZPack (SA×SB),ACC
 →0
ZERO:Z←,0
∇

∇ Z←ZOdd X;L
 →((↑X)=0)/ZERO
 L←1↓X
 Z←2|↑L
 →0
ZERO:Z←0
∇

∇ Z←ZHalf X;L;N;I;C;P
 →((↑X)=0)/ZERO
 →((↑X)=¯1)/NEG
 L←1↓X
 N←⍴L
 C←0
 I←N
LOOP:→(I<1)/DONE
 P←L[I]+C×ZBASE
 L[I]←⌊P÷2
 C←2|P
 I←I-1
 →LOOP
DONE:Z←ZPack 1,L
 →0
NEG:Z←ZNeg ZHalf ZNeg X
 →0
ZERO:Z←,0
∇

∇ Z←ZBits X;W;B
 →((↑X)=¯1)/NEG
 W←X
 B←⍬
LOOP:→((↑W)=0)/DONE
 B←B,ZOdd W
 W←ZHalf W
 →LOOP
DONE:Z←B
 →0
NEG:Z←ZBits ZNeg X
∇

∇ Z←A ZDivMod M;BITS;Q;R;I
 →((↑M)≠1)/ERR
 →((↑A)=¯1)/ERR
 BITS←ZBits A
 Q←,0
 R←,0
 I←⍴BITS
LOOP:→(I<1)/DONE
 R←R ZAdd R
 →(BITS[I]=0)/NO
 R←R ZAdd ZFromInt 1
NO:→((R ZCmp M)<0)/SH
 R←R ZSub M
 Q←(Q ZAdd Q) ZAdd ZFromInt 1
 →NX
SH:Q←Q ZAdd Q
NX:I←I-1
 →LOOP
DONE:Z←(⊂Q),⊂R
 →0
ERR:⎕←'DIV_DOMAIN'
 ⎕ES 'DIV_DOMAIN'
∇

∇ Z←A ZMod M
 Z←⊃(A ZDivMod M)[2]
∇

∇ Z←ZDec X;S;L;H;W;DIG;I;P;D;J
 S←↑X
 →(S=0)/ZERO
 L←1↓X
 DIG←'0123456789'
 H←L[⍴L]
 W←''
HP:→(H=0)/LO
 W←DIG[1+10|H],W
 H←⌊H÷10
 →HP
LO:I←(⍴L)-1
ILO:→(I<1)/SIG
 P←L[I]
 D←9⍴'0'
 J←9
JL:→(J<1)/PUT
 D[J]←DIG[1+10|P]
 P←⌊P÷10
 J←J-1
 →JL
PUT:W←W,D
 I←I-1
 →ILO
SIG:Z←W
 →(S=1)/0
 Z←'-',W
 →0
ZERO:Z←,'0'
∇

∇ Z←ZPow2 E;I
 Z←ZFromInt 1
 I←0
LOOP:→(I≥E)/0
 Z←Z ZAdd Z
 I←I+1
 →LOOP
∇

∇ Z←ZMat M;V;N;I;R;C;J;K
 V←,M
 N←⍴V
 R←↑⍴M
 C←(⍴M)[2]
 Z←(R,C)⍴⊂,0
 I←1
 J←1
 K←1
LOOP:→(I>N)/0
 Z[J;K]←⊂ZFromInt V[I]
 K←K+1
 →(K≤C)/NX
 K←1
 J←J+1
NX:I←I+1
 →LOOP
∇

∇ Z←A ZMM B;RA;CA;CB;I;J;K;S;P
 RA←↑⍴A
 CA←(⍴A)[2]
 CB←(⍴B)[2]
 Z←(RA,CB)⍴⊂,0
 I←1
ILO:→(I>RA)/0
 J←1
JLO:→(J>CB)/IN
 S←,0
 K←1
KLO:→(K>CA)/ST
 P←(⊃A[I;K]) ZMul ⊃B[K;J]
 S←S ZAdd P
 K←K+1
 →KLO
ST:Z[I;J]←⊂S
 J←J+1
 →JLO
IN:I←I+1
 →ILO
∇

∇ Z←ZSelfTest;P;D;A;B;C;RQ
 D←⍕ZPOW62
 →(D≢'4611686018427387904')/BAD
 P←(ZFromInt 3) ZAdd ZFromInt 5
 →((ZDec P)≢,'8')/BAD
 P←(ZFromInt ¯3) ZAdd ZFromInt 5
 →((ZDec P)≢,'2')/BAD
 P←(ZFromInt 5) ZAdd ZFromInt ¯3
 →((ZDec P)≢,'2')/BAD
 P←(ZFromInt ¯5) ZAdd ZFromInt 3
 →((ZDec P)≢'-2')/BAD
 P←(ZFromInt ¯5) ZAdd ZFromInt ¯3
 →((ZDec P)≢'-8')/BAD
 P←ZFromInt 999999999
 P←P ZMul P
 →((ZDec P)≢'999999998000000001')/BAD
 RQ←ZSplitBase 999999998000000001
 →(RQ[1]≠1)/BAD
 →(RQ[2]≠999999998)/BAD
 P←(ZFromInt 10) ZMod ZFromInt 3
 →((ZDec P)≢,'1')/BAD
 A←ZMat 2 2⍴1 2 3 4
 B←ZMat 2 2⍴5 6 7 8
 C←A ZMM B
 →((ZDec ⊃C[1;1])≢'19')/BAD
 →((ZDec ⊃C[1;2])≢'22')/BAD
 →((ZDec ⊃C[2;1])≢'43')/BAD
 →((ZDec ⊃C[2;2])≢'50')/BAD
 P←ZPow2 64
 →((ZDec P)≢'18446744073709551616')/BAD
 P←(ZPow2 64) ZSub ZPow2 32
 P←P ZAdd ZFromInt 1
 →((ZDec P)≢'18446744069414584321')/BAD
 P←ZNeg ZFromInt 12
 →((ZDec P)≢'-12')/BAD
 Z←1
 →0
BAD:⎕←'ZINT_SELFTEST_FAIL'
 ⎕←D
 Z←0
∇
