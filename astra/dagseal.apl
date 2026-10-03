⍝ Astra APL: canonical SHA-512 DAG seal and the seeded SUBLEQ bi-encoder.
⍝ Bytes match j/sha512.ijs node layout SRANOD01 / SRADAG01. The hasher is
⍝ sha512sum over those raw bytes, not over interpreter display text.
⍝ Integers are zints from astra/zint.apl. AGPL-3.0 only.

∇ Z←ZBytes S
 Z←⎕UCS S
∇

∇ Z←ZBe32 N;P
 ZAssertInt N
 →((N≥0)∧N<4294967296)/GO
 ⎕←'BE32_RANGE'
 ⎕ES 'BE32_RANGE'
GO:P←N
 Z←4⍴0
 Z[1]←⌊P÷16777216
 P←16777216|P
 Z[2]←⌊P÷65536
 P←65536|P
 Z[3]←⌊P÷256
 Z[4]←256|P
∇

∇ Z←ZShaRaw Bytes;FN;H;N;L
 FN←'/tmp/astra-preimage.bin'
 H←'wb' ⎕FIO[3] FN
 N←Bytes ⎕FIO[7] H
 N←⎕FIO[4] H
 H←'r' ⎕FIO[24] 'sha512sum /tmp/astra-preimage.bin'
 L←⎕FIO[8] H
 N←⎕FIO[25] H
 →(N≥0)/OK
 ⎕←'SHA_PCLOSE'
 ⎕ES 'SHA_PCLOSE'
OK:→((⍴L)≥128)/DONE
 ⎕←'SHA_SHORT'
 ⎕ES 'SHA_SHORT'
DONE:Z←128↑L
∇

∇ Z←ZHexToBin H;D;I;HI;LO
 D←⎕UCS '0123456789abcdef'
 Z←64⍴0
 I←0
LOOP:→(I≥64)/0
 HI←¯1+D⍳H[1+2×I]
 LO←¯1+D⍳H[2+2×I]
 →((HI≥0)∧LO≥0)/ST
 ⎕←'HEX_DRIFT'
 ⎕ES 'HEX_DRIFT'
ST:Z[I+1]←(16×HI)+LO
 I←I+1
 →LOOP
∇

∇ Z←Role ZNode Tensor;SH;RK;I;VALS;B;D;DB;CNT
 SH←⍴Tensor
 RK←↑⍴⍴Tensor
 VALS←,Tensor
 CNT←↑⍴VALS
 B←ZBytes 'SRANOD01'
 B←B,ZBe32 ↑⍴Role
 B←B,ZBytes Role
 B←B,ZBe32 RK
 I←1
LOOP:→(I>RK)/CNTS
 B←B,ZBe32 SH[I]
 I←I+1
 →LOOP
CNTS:B←B,ZBe32 CNT
 I←1
VLOOP:→(I>CNT)/CHK
 D←ZDec ⊃VALS[I]
 DB←ZBytes D
 B←B,ZBe32 ↑⍴DB
 B←B,DB
 I←I+1
 →VLOOP
CHK:→(∧/(B≥0)∧B<128)/OK
 ⎕←'NON_ASCII_NODE'
 ⎕ES 'NON_ASCII_NODE'
OK:Z←B
∇

∇ Z←ZDag T;EX;PR;W;P;B1;B2;B3;B4;D1;D2;D3;D4;B
 EX←⊃T[1]
 PR←⊃T[2]
 W←⊃T[3]
 P←⊃T[4]
 B1←'exact_head' ZNode EX
 B2←'predicted' ZNode PR
 B3←'weights' ZNode W
 B4←'prime' ZNode P
 D1←ZHexToBin ZShaRaw B1
 D2←ZHexToBin ZShaRaw B2
 D3←ZHexToBin ZShaRaw B3
 D4←ZHexToBin ZShaRaw B4
 B←ZBytes 'SRADAG01'
 B←B,ZBe32 4
 B←B,D1,D2,D3,D4
 Z←⎕UCS ZShaRaw B
∇

∇ Z←Seed ZLCG N;A;M;R;I;V;OUT
 A←ZFromInt 48271
 M←ZFromInt 2147483647
 R←ZFromInt 5
 OUT←⍬
 I←1
LOOP:→(I>N)/DONE
 Seed←(A ZMul Seed) ZMod M
 V←Seed ZMod R
 OUT←OUT,⊂V
 I←I+1
 →LOOP
DONE:Z←(⊂OUT),⊂Seed
∇

∇ Z←Q ZPredRow K;N;I;S;D;T;Zero
 N←⍴Q
 S←,0
 Zero←,0
 I←1
LOOP:→(I>N)/DONE
 D←(⊃K[I]) ZSub ⊃Q[I]
 →((D ZCmp Zero)>0)/NX
 T←(⊃Q[I]) ZMul ⊃K[I]
 S←S ZAdd T
NX:I←I+1
 →LOOP
DONE:Z←S
∇

∇ Z←Q ZPredict K;R;C;I;J
 R←↑⍴Q
 C←↑⍴K
 Z←(R,C)⍴⊂,0
 I←1
ILO:→(I>R)/0
 J←1
JLO:→(J>C)/IN
 Z[I;J]←⊂(Q[I;]) ZPredRow K[J;]
 J←J+1
 →JLO
IN:I←I+1
 →ILO
∇

∇ ZShowMat M;R;C;I;J;ROW;D
 R←↑⍴M
 C←(⍴M)[2]
 I←1
LOOP:→(I>R)/0
 ROW←''
 J←1
JLO:→(J>C)/PR
 D←ZDec ⊃M[I;J]
 →(J=1)/FR
 ROW←ROW,' ',D
 →NX
FR:ROW←D
NX:J←J+1
 →JLO
PR:⎕←ROW
 I←I+1
 →LOOP
∇

∇ Z←ZRunSeeded;S0;R1;AV;S1;R2;BV;A;B;W;Q;K;EX;REF;PR;PM;CELL;T;SE;SM
 S0←ZFromInt 20261002
 R1←S0 ZLCG 16
 AV←⊃R1[1]
 S1←⊃R1[2]
 R2←S1 ZLCG 16
 BV←⊃R2[1]
 A←4 4⍴AV
 B←4 4⍴BV
 W←ZMat 4 4⍴0 1 0 0 0 0 1 0 0 0 0 1 1 0 0 0
 Q←A ZMM W
 K←(⍉B) ZMM W
 EX←Q ZMM ⍉K
 REF←A ZMM B
 PR←Q ZPredict K
 PM←PR
 CELL←(⊃PR[1;1]) ZAdd ZFromInt 1
 PM[1;1]←⊂CELL
 T←(⊂EX),(⊂PR),(⊂W),⊂⊂ZPowP
 SE←ZDag T
 T←(⊂EX),(⊂PM),(⊂W),⊂⊂ZPowP
 SM←ZDag T
 Z←(⊂A),(⊂B),(⊂Q),(⊂K),(⊂EX),(⊂REF),(⊂PR),(⊂PM),(⊂SE),⊂SM
∇

∇ Z←ZPowP
 Z←(ZPow2 64) ZSub ZPow2 32
 Z←Z ZAdd ZFromInt 1
∇
