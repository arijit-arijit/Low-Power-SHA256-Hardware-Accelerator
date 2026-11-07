/*
 * sha256_ref.c - standalone SHA-256 reference model (FIPS 180-4), plain C99.
 *
 * Purpose: independent software answer for the RTL testbenches.
 * Written for readability, mirrors the hardware structure on purpose:
 *   - sha256_compress() = one 512-bit block, 64 rounds (what the RTL core does)
 *   - the working variables a..h are updated exactly like sha256_round.sv
 *
 * Usage:
 *   sha256_ref            print digests + padded blocks for the built-in vectors
 *   sha256_ref -t         also print the working variables after every round
 *                         of the first block of "abc" (used to cross-check the
 *                         round-level unit test)
 *   sha256_ref -s "text"  hash a string (single or multi block, up to 119 bytes)
 *   sha256_ref -k         print the 64 round constants K[0..63], one 8-digit hex
 *                         word per line (the file the K ROM testbench loads), after
 *                         checking the table against its definition: K[t] = first 32
 *                         fractional bits of the cube root of the t-th prime.
 *                         Exit status 1 if any constant disagrees.
 *   sha256_ref -w         print schedule vectors for the message scheduler testbench.
 *                         For each padded block of "abc", "" (empty) and the 56-byte
 *                         two-block message, in that order (4 blocks total), print
 *                         one line with the 512-bit block as 128 hex digits, then
 *                         64 lines with W[0]..W[63] (8 hex digits each).
 *   sha256_ref -c         print end-to-end vectors for the core testbench: one line per
 *                         padded block, for 6 messages (see dump_core_vectors):
 *                           msg_id blk_idx msg_len block(128 hex) h_in(64 hex) h_out(64 hex)
 *                         h_in is the chaining state going in (the initial hash values for
 *                         blk_idx 0), h_out the state after that block; the h_out of a
 *                         message's last block is its SHA-256 digest.
 */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))

static const uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

static const uint32_t H_INIT[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

/* Message schedule: expand one 64-byte block into W[0..63] (FIPS 180-4, 6.2.2 step 1). */
static void sha256_schedule(const uint8_t block[64], uint32_t W[64])
{
    int t;

    for (t = 0; t < 16; t++)
        W[t] = ((uint32_t)block[4 * t] << 24) | ((uint32_t)block[4 * t + 1] << 16) |
               ((uint32_t)block[4 * t + 2] << 8) | (uint32_t)block[4 * t + 3];
    for (t = 16; t < 64; t++) {
        uint32_t s0 = ROTR(W[t - 15], 7) ^ ROTR(W[t - 15], 18) ^ (W[t - 15] >> 3);
        uint32_t s1 = ROTR(W[t - 2], 17) ^ ROTR(W[t - 2], 19) ^ (W[t - 2] >> 10);
        W[t] = W[t - 16] + s0 + W[t - 7] + s1;
    }
}

/* Compress one 64-byte block into state[8]. If trace != 0, print a..h after each round. */
static void sha256_compress(uint32_t state[8], const uint8_t block[64], int trace)
{
    uint32_t W[64];
    uint32_t a, b, c, d, e, f, g, h;
    int t;

    sha256_schedule(block, W);

    a = state[0]; b = state[1]; c = state[2]; d = state[3];
    e = state[4]; f = state[5]; g = state[6]; h = state[7];

    for (t = 0; t < 64; t++) {
        uint32_t S1 = ROTR(e, 6) ^ ROTR(e, 11) ^ ROTR(e, 25);
        uint32_t ch = (e & f) ^ (~e & g);
        uint32_t T1 = h + S1 + ch + K[t] + W[t];
        uint32_t S0 = ROTR(a, 2) ^ ROTR(a, 13) ^ ROTR(a, 22);
        uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint32_t T2 = S0 + maj;
        h = g; g = f; f = e; e = d + T1;
        d = c; c = b; b = a; a = T1 + T2;
        if (trace)
            printf("t=%2d K=%08x W=%08x  a=%08x b=%08x c=%08x d=%08x e=%08x f=%08x g=%08x h=%08x\n",
                   t, K[t], W[t], a, b, c, d, e, f, g, h);
    }

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

/* Pad msg (len <= 119 bytes) into 1 or 2 blocks. Returns number of blocks. */
static int sha256_pad(const uint8_t *msg, size_t len, uint8_t out[128])
{
    size_t total = (len + 1 + 8 <= 64) ? 64 : 128;
    uint64_t bits = (uint64_t)len * 8;
    int i;

    memset(out, 0, 128);
    memcpy(out, msg, len);
    out[len] = 0x80;
    for (i = 0; i < 8; i++)
        out[total - 1 - i] = (uint8_t)(bits >> (8 * i));
    return (int)(total / 64);
}

/*
 * Recompute K[t] from its definition (FIPS 180-4, 4.2.2) and compare with the table.
 * cbrt(p) < 7 for the first 64 primes, so a double (53-bit mantissa) keeps ~50
 * fractional bits - plenty for the 32 bits we need. Returns the number of mismatches.
 */
static int check_k_constants(void)
{
    int found = 0, errors = 0;
    uint32_t n, d;

    for (n = 2; found < 64; n++) {
        int is_prime = 1;
        double root, frac;
        uint32_t expect;

        for (d = 2; d * d <= n; d++)
            if (n % d == 0) { is_prime = 0; break; }
        if (!is_prime)
            continue;

        root = cbrt((double)n);
        frac = root - floor(root);
        expect = (uint32_t)(frac * 4294967296.0);
        if (expect != K[found]) {
            fprintf(stderr, "K[%d] mismatch (prime %u): table %08x, derived %08x\n",
                    found, (unsigned)n, K[found], expect);
            errors++;
        }
        found++;
    }
    return errors;
}

static void print_hex_bytes(const uint8_t *p, int n)
{
    int i;
    for (i = 0; i < n; i++)
        printf("%02x", p[i]);
}

/* -w: padded blocks and their W[0..63], for the message scheduler testbench */
static void dump_schedule_vectors(void)
{
    static const char *const msgs[3] = {
        "abc", "", "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"};
    int m, b, t;

    for (m = 0; m < 3; m++) {
        uint8_t padded[128];
        int nblocks = sha256_pad((const uint8_t *)msgs[m], strlen(msgs[m]), padded);

        for (b = 0; b < nblocks; b++) {
            uint32_t W[64];

            print_hex_bytes(padded + 64 * b, 64);
            printf("\n");
            sha256_schedule(padded + 64 * b, W);
            for (t = 0; t < 64; t++)
                printf("%08x\n", W[t]);
        }
    }
}

static void print_state_hex(const uint32_t st[8])
{
    int j;
    for (j = 0; j < 8; j++)
        printf("%08x", st[j]);
}

/* -c: per-block records (block, state in, state out) for the end-to-end core testbench */
static void dump_core_vectors(void)
{
    char a55[56], a64[65], a119[120];
    const char *msgs[6];
    int m, b;

    memset(a55, 'a', 55);   a55[55] = '\0';
    memset(a64, 'a', 64);   a64[64] = '\0';
    memset(a119, 'a', 119); a119[119] = '\0';

    msgs[0] = "abc";
    msgs[1] = "";
    msgs[2] = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    msgs[3] = a55;      /* longest message that fits one block with its padding */
    msgs[4] = a64;      /* exactly one data block; second block is padding only */
    msgs[5] = a119;     /* longest message this reference pads (two blocks) */

    for (m = 0; m < 6; m++) {
        uint8_t padded[128];
        uint32_t st[8];
        size_t len = strlen(msgs[m]);
        int nblocks = sha256_pad((const uint8_t *)msgs[m], len, padded);

        memcpy(st, H_INIT, sizeof st);
        for (b = 0; b < nblocks; b++) {
            printf("%d %d %zu ", m, b, len);
            print_hex_bytes(padded + 64 * b, 64);
            printf(" ");
            print_state_hex(st);
            sha256_compress(st, padded + 64 * b, 0);
            printf(" ");
            print_state_hex(st);
            printf("\n");
        }
    }
}

static void run(const char *label, const uint8_t *msg, size_t len, int trace)
{
    uint8_t padded[128];
    uint32_t st[8];
    int nblocks, i;

    nblocks = sha256_pad(msg, len, padded);
    memcpy(st, H_INIT, sizeof st);

    printf("== %s (len=%zu bytes, %d block%s)\n", label, len, nblocks, nblocks > 1 ? "s" : "");
    for (i = 0; i < nblocks; i++) {
        printf("block%d = ", i);
        print_hex_bytes(padded + 64 * i, 64);
        printf("\n");
        sha256_compress(st, padded + 64 * i, trace && i == 0);
        printf("state after block%d = ", i);
        {
            int j;
            for (j = 0; j < 8; j++)
                printf("%08x", st[j]);
        }
        printf("\n");
    }
    printf("digest = ");
    {
        int j;
        for (j = 0; j < 8; j++)
            printf("%08x", st[j]);
    }
    printf("\n\n");
}

int main(int argc, char **argv)
{
    int trace = 0;
    int dump_k = 0;
    int dump_w = 0;
    int dump_c = 0;
    int i;
    const char *custom = NULL;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-t") == 0)
            trace = 1;
        else if (strcmp(argv[i], "-k") == 0)
            dump_k = 1;
        else if (strcmp(argv[i], "-w") == 0)
            dump_w = 1;
        else if (strcmp(argv[i], "-c") == 0)
            dump_c = 1;
        else if (strcmp(argv[i], "-s") == 0 && i + 1 < argc)
            custom = argv[++i];
    }

    if (dump_w) {
        dump_schedule_vectors();
        return 0;
    }

    if (dump_c) {
        dump_core_vectors();
        return 0;
    }

    if (dump_k) {
        int bad = check_k_constants();
        if (bad) {
            fprintf(stderr, "K table check FAILED: %d mismatches\n", bad);
            return 1;
        }
        fprintf(stderr, "K table check passed: 64/64 constants match the cube-root definition\n");
        for (i = 0; i < 64; i++)
            printf("%08x\n", K[i]);
        return 0;
    }

    if (custom) {
        size_t n = strlen(custom);
        if (n > 119) {
            fprintf(stderr, "message too long (max 119 bytes)\n");
            return 1;
        }
        run("custom", (const uint8_t *)custom, n, trace);
        return 0;
    }

    run("empty", (const uint8_t *)"", 0, 0);
    run("abc", (const uint8_t *)"abc", 3, trace);
    {
        const char *m2 = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        run("448-bit two-block message", (const uint8_t *)m2, strlen(m2), 0);
    }
    return 0;
}
