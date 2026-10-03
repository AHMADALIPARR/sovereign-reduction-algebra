⍝ Astra N=128 zint matmul and DAG seal timings.
⍝ Seconds are integer microseconds from ⎕FIO[50] 1000000, formatted by
⍝ splitting the decimal digits. No float timer. AGPL-3.0 only.

∇ Z←ZSecs US;D;SEC;FRAC
 D←⍕US
 →((⍴D)>6)/BIG
 D←((6-⍴D)⍴'0'),D
 Z←'0.',D
 →0
BIG:SEC←(¯6)↓D
 FRAC←(¯6)↑D
 Z←SEC,'.',FRAC
∇

∇ Z←N ZFill Off;I;V;M
 V←⍬
 I←0
 M←N×N
LOOP:→(I≥M)/SH
 V←V,⊂ZFromInt 5|Off+I
 I←I+1
 →LOOP
SH:Z←(N,N)⍴V
∇

∇ Z←ZSum M;I;V;S
 V←,M
 S←,0
 I←1
LOOP:→(I>⍴V)/DONE
 S←S ZAdd ⊃V[I]
 I←I+1
 →LOOP
DONE:Z←S
∇

∇ Z←N ZBench Trials;A;B;C;I;T0;T1;S;NB
 ⎕←'BENCH_V1'
 ⎕←'LANGUAGE'
 ⎕←'GNU APL'
 ⎕←'TIMER'
 ⎕←'⎕FIO[50] 1000000'
 A←N ZFill 0
 B←N ZFill N×N
 T0←⎕FIO[50] 1000000
 C←A ZMM B
 T1←⎕FIO[50] 1000000
 ⎕←'UNTIMED_US'
 ⎕←T1-T0
 S←ZDec ZSum C
 ⎕←'CHECKSUM'
 ⎕←S
 ⎕←'RECORD'
 ⎕←'SIZE'
 ⎕←⍕N
 ⎕←'OP'
 ⎕←'unmasked_integer_matmul'
 ⎕←'TRIALS'
 ⎕←⍕Trials
 ⎕←'SECONDS'
 I←1
LOOP:→(I>Trials)/SEAL
 T0←⎕FIO[50] 1000000
 C←A ZMM B
 T1←⎕FIO[50] 1000000
 ⎕←ZSecs T1-T0
 I←I+1
 →LOOP
SEAL:P←⊂ZPowP
 W←ZMat 4 4⍴0 1 0 0 0 0 1 0 0 0 0 1 1 0 0 0
 ⎕←'RECORD'
 ⎕←'SIZE'
 ⎕←⍕N
 ⎕←'OP'
 ⎕←'sha512_dag_seal'
 ⎕←'TRIALS'
 ⎕←⍕Trials
 ⎕←'SECONDS'
 I←1
SLOOP:→(I>Trials)/DONE
 T0←⎕FIO[50] 1000000
 HEX←ZDag (⊂C),(⊂C),(⊂W),⊂P
 T1←⎕FIO[50] 1000000
 ⎕←ZSecs T1-T0
 I←I+1
 →SLOOP
DONE:NB←⍴'exact_head' ZNode C
 ⎕←'SEAL'
 ⎕←HEX
 ⎕←'NODE_BYTES'
 ⎕←⍕NB
 ⎕←'BENCH_DONE'
 Z←HEX
∇

HEX←128 ZBench 3
)OFF 0
