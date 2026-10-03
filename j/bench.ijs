NB. Measured benches only. Times are 6!:2, formatted 0j6 (1e-6 s).
NB. Matrices are extended integers, never float.
NB. A[i,j] = (i*n+j) mod 5. B[i,j] = (n*n + i*n + j) mod 5.
NB. sha512_dag_seal calls dag_seal_hex on
NB.   exact = product, predicted = product, weights = the 4x4 permutation,
NB.   prime = Goldilocks p.
NB. The routed head is not part of this timing.
NB. N=1024 seal is one trial. N=128 is three.

load_seal =: 3 : 0
  this =. > {: 4!:3 ''
  dir =. (>: this i: '/') {. this
  load dir , 'sha512.ijs'
  1
)
load_seal ''

fmtsec =: 3 : '0j6 ": y'
clean_int =: 3 : 0
  s =. , ": y
  s =. s -. ' '
  '-' (I. s e. '_¯') } s
)

P =: 18446744069414584321x
PERM4 =: x: 4 4 $ 0 1 0 0 0 0 1 0 0 0 0 1 1 0 0 0

echo 'BENCH_V1'
echo 'LANGUAGE'
echo 'J'
echo 'VERSION'
echo 9!:14 ''
echo 'TIMER'
echo '6!:2'

run_mm =: 4 : 0
  n =. x
  trials =. y
  A =. x: (n , n) $ 5 | i. n * n
  B =. x: (n , n) $ 5 | (n * n) + i. n * n
  C =. A +/ .* B
  if. (3!:0 C) e. 8 16 do.
    echo 'FLOAT_REFUSED'
    exit 1
  end.
  echo 'RECORD'
  echo 'SIZE'
  echo clean_int n
  echo 'OP'
  echo 'unmasked_integer_matmul'
  echo 'TRIALS'
  echo clean_int trials
  echo 'SECONDS'
  for. i. trials do.
    echo fmtsec 6!:2 'C =. A +/ .* B'
  end.
  if. (3!:0 C) e. 8 16 do.
    echo 'FLOAT_REFUSED'
    exit 1
  end.
  echo 'CHECKSUM'
  echo clean_int +/ , C
  echo 'RESULT_TYPE'
  echo clean_int 3!:0 {. , C
  C
)

run_seal =: 4 : 0
  'n C' =. x
  trials =. y
  if. (3!:0 C) e. 8 16 do.
    echo 'FLOAT_REFUSED'
    exit 1
  end.
  echo 'RECORD'
  echo 'SIZE'
  echo clean_int n
  echo 'OP'
  echo 'sha512_dag_seal'
  echo 'TRIALS'
  echo clean_int trials
  echo 'SECONDS'
  for. i. trials do.
    echo fmtsec 6!:2 's =. dag_seal_hex C ; C ; PERM4 ; P'
  end.
  echo 'CHECKSUM'
  echo s
  echo 'NODE_BYTES'
  echo clean_int # 'exact_head' node_bytes C
  echo 'RESULT_TYPE'
  echo 'sha512'
  s
)

C128 =: 128 run_mm 3
s128 =: (128 ; C128) run_seal 3
C1024 =: 1024 run_mm 3
s1024 =: (1024 ; C1024) run_seal 1
echo 'BENCH_DONE'
exit 0
