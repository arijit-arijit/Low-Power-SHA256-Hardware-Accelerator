/* check_golden.c - independent check of verification/vectors/golden.hex.
 * Recomputes the 20 chained SHA-256 compression results used by tb_sha256_power.sv
 * (xorshift32 data, seed 0x1badb002, 16 words per block, chaining from the standard IV)
 * with its own small SHA-256 compression function and compares them with golden.hex.
 * Build/run:  gcc -std=c99 -O2 -o check_golden check_golden.c && ./check_golden ../vectors/golden.hex
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

static const uint32_t K[64] = {
0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2};
#define R(x,n) (((x)>>(n))|((x)<<(32-(n))))

static void compress(uint32_t st[8], const uint32_t blk[16]) {
    uint32_t w[64], v[8]; int t;
    for (t = 0; t < 16; t++) w[t] = blk[t];
    for (t = 16; t < 64; t++) {
        uint32_t s0 = R(w[t-15],7) ^ R(w[t-15],18) ^ (w[t-15]>>3);
        uint32_t s1 = R(w[t-2],17) ^ R(w[t-2],19) ^ (w[t-2]>>10);
        w[t] = w[t-16] + s0 + w[t-7] + s1;
    }
    memcpy(v, st, sizeof v);
    for (t = 0; t < 64; t++) {
        uint32_t S1 = R(v[4],6) ^ R(v[4],11) ^ R(v[4],25);
        uint32_t ch = (v[4] & v[5]) ^ (~v[4] & v[6]);
        uint32_t t1 = v[7] + S1 + ch + K[t] + w[t];
        uint32_t S0 = R(v[0],2) ^ R(v[0],13) ^ R(v[0],22);
        uint32_t mj = (v[0] & v[1]) ^ (v[0] & v[2]) ^ (v[1] & v[2]);
        uint32_t t2 = S0 + mj;
        v[7]=v[6]; v[6]=v[5]; v[5]=v[4]; v[4]=v[3]+t1;
        v[3]=v[2]; v[2]=v[1]; v[1]=v[0]; v[0]=t1+t2;
    }
    for (t = 0; t < 8; t++) st[t] += v[t];
}
static uint32_t xs(uint32_t v) { v ^= v << 13; v ^= v >> 17; v ^= v << 5; return v; }

int main(int argc, char **argv) {
    uint32_t st[8] = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
    uint32_t s = 0x1badb002; int n, i, bad = 0;
    FILE *f = fopen(argc > 1 ? argv[1] : "golden.hex", "r");
    if (!f) { perror("golden.hex"); return 2; }
    for (n = 0; n < 20; n++) {
        uint32_t blk[16]; char line[256], got[65];
        for (i = 0; i < 16; i++) { s = xs(s); blk[15 - i] = s; }   /* tb puts word i at bits [32*i +: 32]; SHA-256 reads the block MSB word first */
        compress(st, blk);
        for (i = 0; i < 8; i++) sprintf(got + 8*i, "%08x", st[i]);
        if (!fgets(line, sizeof line, f)) { printf("golden.hex too short at %d\n", n); return 1; }
        if (strncmp(line, got, 64)) { printf("MISMATCH block %d\n  got  %s\n  file %.64s\n", n, got, line); bad++; }
    }
    fclose(f);
    printf(bad ? "FAIL: %d mismatches\n" : "PASS: 20/20 golden digests recomputed independently\n", bad);
    return bad != 0;
}
