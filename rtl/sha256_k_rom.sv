// sha256_k_rom.sv
// SHA-256 round-constant ROM: K[0] .. K[63] (FIPS 180-4, section 4.2.2).
//
// Purely combinational lookup: no clock, no reset, no state.
//   k = K[idx]
//
// Interface
//   idx : round number t, 6 bits (0..63). Every possible binary value is a valid
//         round, so there is NO invalid binary index. The core's 7-bit round
//         counter must drive only its low 6 bits here (idx = round_cnt[5:0]).
//   k   : the 32-bit constant for round t.
//
// Unknown index (simulation only): if idx contains X or Z, no case item matches
// and k is driven to X, so a bad index shows up as X on the waveform instead of
// silently returning a valid-looking constant. In hardware idx is always 0 or 1,
// so the default branch is never taken and synthesis treats it as don't-care.
//
// The constants are the first 32 fractional bits of the cube roots of the first
// 64 primes. The table below was generated from `ref/sha256_ref -k`, which checks
// it against that definition; tb/tb_sha256_k_rom.sv checks all 64 entries.
module sha256_k_rom (
    input  logic [5:0]  idx,
    output logic [31:0] k
);

    always_comb begin
        case (idx)
            6'd0 : k = 32'h428a2f98;
            6'd1 : k = 32'h71374491;
            6'd2 : k = 32'hb5c0fbcf;
            6'd3 : k = 32'he9b5dba5;
            6'd4 : k = 32'h3956c25b;
            6'd5 : k = 32'h59f111f1;
            6'd6 : k = 32'h923f82a4;
            6'd7 : k = 32'hab1c5ed5;
            6'd8 : k = 32'hd807aa98;
            6'd9 : k = 32'h12835b01;
            6'd10: k = 32'h243185be;
            6'd11: k = 32'h550c7dc3;
            6'd12: k = 32'h72be5d74;
            6'd13: k = 32'h80deb1fe;
            6'd14: k = 32'h9bdc06a7;
            6'd15: k = 32'hc19bf174;
            6'd16: k = 32'he49b69c1;
            6'd17: k = 32'hefbe4786;
            6'd18: k = 32'h0fc19dc6;
            6'd19: k = 32'h240ca1cc;
            6'd20: k = 32'h2de92c6f;
            6'd21: k = 32'h4a7484aa;
            6'd22: k = 32'h5cb0a9dc;
            6'd23: k = 32'h76f988da;
            6'd24: k = 32'h983e5152;
            6'd25: k = 32'ha831c66d;
            6'd26: k = 32'hb00327c8;
            6'd27: k = 32'hbf597fc7;
            6'd28: k = 32'hc6e00bf3;
            6'd29: k = 32'hd5a79147;
            6'd30: k = 32'h06ca6351;
            6'd31: k = 32'h14292967;
            6'd32: k = 32'h27b70a85;
            6'd33: k = 32'h2e1b2138;
            6'd34: k = 32'h4d2c6dfc;
            6'd35: k = 32'h53380d13;
            6'd36: k = 32'h650a7354;
            6'd37: k = 32'h766a0abb;
            6'd38: k = 32'h81c2c92e;
            6'd39: k = 32'h92722c85;
            6'd40: k = 32'ha2bfe8a1;
            6'd41: k = 32'ha81a664b;
            6'd42: k = 32'hc24b8b70;
            6'd43: k = 32'hc76c51a3;
            6'd44: k = 32'hd192e819;
            6'd45: k = 32'hd6990624;
            6'd46: k = 32'hf40e3585;
            6'd47: k = 32'h106aa070;
            6'd48: k = 32'h19a4c116;
            6'd49: k = 32'h1e376c08;
            6'd50: k = 32'h2748774c;
            6'd51: k = 32'h34b0bcb5;
            6'd52: k = 32'h391c0cb3;
            6'd53: k = 32'h4ed8aa4a;
            6'd54: k = 32'h5b9cca4f;
            6'd55: k = 32'h682e6ff3;
            6'd56: k = 32'h748f82ee;
            6'd57: k = 32'h78a5636f;
            6'd58: k = 32'h84c87814;
            6'd59: k = 32'h8cc70208;
            6'd60: k = 32'h90befffa;
            6'd61: k = 32'ha4506ceb;
            6'd62: k = 32'hbef9a3f7;
            6'd63: k = 32'hc67178f2;
            default: k = 32'hxxxxxxxx;
        endcase
    end

endmodule
