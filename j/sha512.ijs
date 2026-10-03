NB. SHA-512 (FIPS 180-4) and the bi-encoder DAG seal.
NB. A word is two uint32 halves (hi, lo), each kept in 0..4294967295 so
NB. J b. never sees a value >= 2^63 (those are not exact machine integers).
NB.
NB. Canonical node preimage, big-endian, no JSON, no floats:
NB.   8 bytes ASCII "SRANOD01"
NB.   uint32be role_len, then that many ASCII bytes of the role
NB.   uint32be rank, then rank uint32be dimensions
NB.   uint32be count (product of the dimensions; rank 0 has count 1)
NB.   count integers in row-major order (last axis fastest). Each is
NB.     uint32be nbytes, then nbytes of ASCII decimal:
NB.     optional leading "-", no "+", no leading zeros, zero is "0"
NB. Node digest = SHA-512 of that preimage (64 bytes).
NB.
NB. DAG preimage:
NB.   8 bytes ASCII "SRADAG01"
NB.   uint32be child count
NB.   that many raw 64-byte digests, fixed order:
NB.     exact_head, predicted, weights, prime
NB. The seal is the lowercase hex SHA-512 of the DAG preimage.
NB. verify recomputes the seal from the tensors and compares.

M32 =: 4294967295
NIST_EMPTY =: 'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e'
NIST_ABC =: 'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f'
NIST_LONG =: '8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909'
NIST_LONG_MSG =: 'abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu'

be32 =: 3 : '(4 # 256) #: y'

hexw =: 3 : 0
  d =. '0123456789abcdef' i. y
  if. 16 e. d do.
    echo 'BADHEX'
    exit 1
  end.
  (16 #. 8 {. d) , (16 #. 8 }. d)
)

H512 =: hexw "1 (8 16 $ '6a09e667f3bcc908bb67ae8584caa73b3c6ef372fe94f82ba54ff53a5f1d36f1510e527fade682d19b05688c2b3e6c1f1f83d9abfb41bd6b5be0cd19137e2179')
K512 =: hexw "1 (80 16 $ '428a2f98d728ae227137449123ef65cdb5c0fbcfec4d3b2fe9b5dba58189dbbc3956c25bf348b53859f111f1b605d019923f82a4af194f9bab1c5ed5da6d8118d807aa98a303024212835b0145706fbe243185be4ee4b28c550c7dc3d5ffb4e272be5d74f27b896f80deb1fe3b1696b19bdc06a725c71235c19bf174cf692694e49b69c19ef14ad2efbe4786384f25e30fc19dc68b8cd5b5240ca1cc77ac9c652de92c6f592b02754a7484aa6ea6e4835cb0a9dcbd41fbd476f988da831153b5983e5152ee66dfaba831c66d2db43210b00327c898fb213fbf597fc7beef0ee4c6e00bf33da88fc2d5a79147930aa72506ca6351e003826f142929670a0e6e7027b70a8546d22ffc2e1b21385c26c9264d2c6dfc5ac42aed53380d139d95b3df650a73548baf63de766a0abb3c77b2a881c2c92e47edaee692722c851482353ba2bfe8a14cf10364a81a664bbc423001c24b8b70d0f89791c76c51a30654be30d192e819d6ef5218d69906245565a910f40e35855771202a106aa07032bbd1b819a4c116b8d2d0c81e376c085141ab532748774cdf8eeb9934b0bcb5e19b48a8391c0cb3c5c95a634ed8aa4ae3418acb5b9cca4f7763e373682e6ff3d6b2b8a3748f82ee5defb2fc78a5636f43172f6084c87814a1f0ab728cc702081a6439ec90befffa23631e28a4506cebde82bde9bef9a3f7b2c67915c67178f2e372532bca273eceea26619cd186b8c721c0c207eada7dd6cde0eb1ef57d4f7fee6ed17806f067aa72176fba0a637dc5a2c898a6113f9804bef90dae1b710b35131c471b28db77f523047d8432caab7b40c724933c9ebe0a15c9bebc431d67c49c100d4c4cc5d4becb3e42b6597f299cfc657e2a5fcb6fab3ad6faec6c44198c4a475817')

andw =: 4 : 0
  'ah al' =. x
  'bh bl' =. y
  (ah (17 b.) bh) , (al (17 b.) bl)
)

orw =: 4 : 0
  'ah al' =. x
  'bh bl' =. y
  (ah (23 b.) bh) , (al (23 b.) bl)
)

xorw =: 4 : 0
  'ah al' =. x
  'bh bl' =. y
  (ah (22 b.) bh) , (al (22 b.) bl)
)

notw =: 3 : '(M32 , M32) xorw y'

addw =: 4 : 0
  'ah al' =. x
  'bh bl' =. y
  s =. al + bl
  lo =. M32 (17 b.) s
  carry =. _32 (33 b.) s
  t =. ah + bh + carry
  hi =. M32 (17 b.) t
  hi , lo
)

shrw =: 4 : 0
  n =. x
  'hi lo' =. y
  if. n = 0 do. (M32 (17 b.) hi) , (M32 (17 b.) lo) return. end.
  if. n >: 64 do. 0 0 return. end.
  if. n >: 32 do.
    s =. n - 32
    if. s = 0 do. 0 , (M32 (17 b.) hi) return. end.
    0 , (M32 (17 b.) ((- s) (33 b.) hi)) return.
  end.
  newhi =. M32 (17 b.) ((- n) (33 b.) hi)
  los =. M32 (17 b.) ((- n) (33 b.) lo)
  lowmask =. <: 2 ^ n
  cross =. M32 (17 b.) ((32 - n) (33 b.) (lowmask (17 b.) hi))
  newlo =. M32 (17 b.) los + cross
  newhi , newlo
)

shlw =: 4 : 0
  n =. x
  'hi lo' =. y
  if. n = 0 do. (M32 (17 b.) hi) , (M32 (17 b.) lo) return. end.
  if. n >: 64 do. 0 0 return. end.
  if. n >: 32 do.
    s =. n - 32
    if. s = 0 do. (M32 (17 b.) lo) , 0 return. end.
    (M32 (17 b.) (s (33 b.) lo)) , 0 return.
  end.
  newlo =. M32 (17 b.) (n (33 b.) lo)
  cross =. M32 (17 b.) ((- (32 - n)) (33 b.) lo)
  newhi =. M32 (17 b.) ((n (33 b.) hi) + cross)
  newhi , newlo
)

rotrw =: 4 : 0
  n =. 64 | x
  if. n = 0 do. y return. end.
  (n shrw y) orw ((64 - n) shlw y)
)

pack8 =: 3 : 0
  (256 #. 4 {. y) , (256 #. 4 }. y)
)

be8 =: 3 : 0
  'hi lo' =. y
  (be32 hi) , (be32 lo)
)

hex_bytes =: 3 : 0
  nib =. (16 16 & #:)"0 y
  , '0123456789abcdef' {~ nib
)

sha512 =: 3 : 0
  msg =. , y
  nb =. # msg
  bitlen =. 8 * nb
  msg =. msg , 128
  while. 112 ~: 128 | # msg do.
    msg =. msg , 0
  end.
  lo =. M32 (17 b.) bitlen
  hi =. M32 (17 b.) (_32 (33 b.) bitlen)
  msg =. msg , (8 $ 0) , be8 (hi , lo)
  if. 0 ~: 128 | # msg do.
    echo 'PAD_FAIL'
    exit 1
  end.
  state =. H512
  nblk =. <. (# msg) % 128
  for_bi. i. nblk do.
    off =. 128 * bi
    blk =. (off + i. 128) { msg
    ws =. 80 2 $ 0
    for_j. i. 16 do.
      ws =. (pack8 ((8 * j) + i. 8) { blk) j } ws
    end.
    for_j. 16 + i. 64 do.
      w15 =. (j - 15) { ws
      w2 =. (j - 2) { ws
      w16 =. (j - 16) { ws
      w7 =. (j - 7) { ws
      s0 =. ((1 rotrw w15) xorw (8 rotrw w15)) xorw (7 shrw w15)
      s1 =. ((19 rotrw w2) xorw (61 rotrw w2)) xorw (6 shrw w2)
      nw =. ((w16 addw s0) addw w7) addw s1
      ws =. nw j } ws
    end.
    a =. 0 { state
    b =. 1 { state
    c =. 2 { state
    d =. 3 { state
    e =. 4 { state
    f =. 5 { state
    g =. 6 { state
    h =. 7 { state
    for_i. i. 80 do.
      s1 =. ((14 rotrw e) xorw (18 rotrw e)) xorw (41 rotrw e)
      chv =. (e andw f) xorw ((notw e) andw g)
      t1 =. (((h addw s1) addw chv) addw (i { K512)) addw (i { ws)
      s0 =. ((28 rotrw a) xorw (34 rotrw a)) xorw (39 rotrw a)
      maj =. ((a andw b) xorw (a andw c)) xorw (b andw c)
      t2 =. s0 addw maj
      h =. g
      g =. f
      f =. e
      e =. d addw t1
      d =. c
      c =. b
      b =. a
      a =. t1 addw t2
    end.
    acc =. 8 2 $ a , b , c , d , e , f , g , h
    state =. state addw"1 acc
  end.
  out =. 0 $ 0
  for_r. state do.
    out =. out , be8 r
  end.
  out
)

dec_bytes =: 3 : 0
  s =. ": x: y
  s =. s -. ' '
  s =. '-' (I. s e. '_¯') } s
  a. i. s
)

enc_int =: 3 : 0
  db =. dec_bytes y
  (be32 # db) , db
)

NB. x is the role string. y is an exact integer tensor (scalar allowed).
node_bytes =: 4 : 0
  role =. x
  tensor =. y
  t =. 3!:0 tensor
  if. t e. 8 16 do.
    echo 'FLOAT_REFUSED'
    exit 1
  end.
  tensor =. x: tensor
  shp =. $ tensor
  rank =. # shp
  vals =. , tensor
  cnt =. # vals
  rb =. a. i. role
  b =. (a. i. 'SRANOD01') , (be32 # rb) , rb , (be32 rank)
  if. rank > 0 do.
    b =. b , , be32 "0 shp
  end.
  b =. b , be32 cnt
  b , ; enc_int each vals
)

NB. y is a boxed list of 64-byte integer vectors, parent order.
dag_preimage =: 3 : 0
  kids =. y
  ((a. i. 'SRADAG01') , be32 # kids) , ; kids
)

NB. y is exact ; predicted ; weights ; prime
dag_seal_hex =: 3 : 0
  'ex pr wt prme' =. y
  d1 =. sha512 ('exact_head' node_bytes ex)
  d2 =. sha512 ('predicted' node_bytes pr)
  d3 =. sha512 ('weights' node_bytes wt)
  d4 =. sha512 ('prime' node_bytes prme)
  hex_bytes sha512 dag_preimage (d1 ; d2 ; d3 ; d4)
)

NB. x is claimed lowercase hex. y is the four tensors. 1 iff equal.
verify_dag =: 4 : 0
  x -: dag_seal_hex y
)

sha512_vectors =: 3 : 0
  e =. hex_bytes sha512 (0 $ 0)
  a =. hex_bytes sha512 a. i. 'abc'
  g =. hex_bytes sha512 a. i. NIST_LONG_MSG
  e ; a ; g
)

sha512_selftest =: 3 : 0
  'e a g' =. sha512_vectors ''
  if. -. (e -: NIST_EMPTY) *. (a -: NIST_ABC) *. (g -: NIST_LONG) do.
    echo 'SHA512_SELFTEST_FAIL'
    echo e
    echo a
    echo g
    exit 1
  end.
  1
)

sha512_selftest ''
