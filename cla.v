/**
* Adds two input bits, putting the result into a sum bit.
* Takes in a carry bit.
**/
module full_adder(a, b, cin, s);
    input a, b, cin;
    output s;

    // sum bit determined by a XOR b XOR cin
    assign s = a ^ b ^ cin;
endmodule

/**
* Generates the generate, propagate and carry out bits.
**/
module carry_block(a, b, cin, g, p, cout);
    input a, b, cin;
    output g, p, cout;

    // create wires for generate and propagate bits
    wire g, p;

    assign g = a & b;
    assign p = a | b;

    // use generate and propagate bits to generate carry-out
    assign cout = g | (p & cin);
endmodule

/**
* 4 bit carry adder. Uses 4 full adders.
* Mode of 1 means subtraction, mode of 0 means addition.
**/
module carry_lookahead_4bit(a, b, cin, sum, cout, mode);
    input[3:0] a, b; // 4-bit inputs to add
    input mode, cin;
    output[3:0] sum;
    output cout;

    // create subtract mode
    wire[3:0] negb;
    assign negb = ~b;

    // wires to store generate and propagate bits
    wire p0, p1, p2, p3;
    wire g0, g1, g2, g3;

    // wire cx_y connects the carry out for bit x to the carry in for bit y
    wire c0_1;
    wire c1_2;
    wire c2_3;
    wire c3_4;

    full_adder  f0(.a(a[0]), .b(mode ? negb[0] : b[0]), .cin(cin), .s(sum[0]));
    carry_block c0(.a(a[0]), .b(mode ? negb[0] : b[0]), .cin(cin), .p(p0), .g(g0), .cout(c0_1));

    full_adder  f1(.a(a[1]), .b(mode ? negb[1] : b[1]), .cin(c0_1), .s(sum[1]));
    carry_block c1(.a(a[1]), .b(mode ? negb[1] : b[1]), .cin(c0_1), .p(p1), .g(g1), .cout(c1_2));

    full_adder  f2(.a(a[2]), .b(mode ? negb[2] : b[2]), .cin(c1_2), .s(sum[2]));
    carry_block c2(.a(a[2]), .b(mode ? negb[2] : b[2]), .cin(c1_2), .p(p2), .g(g2), .cout(c2_3));

    full_adder  f3(.a(a[3]), .b(mode ? negb[3] : b[3]), .cin(c2_3), .s(sum[3]));
    carry_block c3(.a(a[3]), .b(mode ? negb[3] : b[3]), .cin(c2_3), .p(p3), .g(g3), .cout(c3_4));
    
    // generate carry-out of whole module
    assign cout = g3 | (p3 & c3_4);
endmodule

/**
* 16-bit CLA, created from 4 4-bit CLAs. Mode of 1 means subtraction, mode of 0 means addition.
* Outputs the relevant flag bit data into a 3-bit register.
**/
module carry_lookahead(a, b, sum, overflow, mode);
    input[15:0] a, b;
    input mode;
    output[15:0] sum;
    output overflow;

    wire[15:0] b_in;
    wire[15:0] CLASum;

    // wire cx_y connects the carry out of module x to the carry in of module y
    wire c0_1;
    wire c1_2;
    wire c2_3;
    wire c3_4;

    // largest negative and positive values
    wire[15:0] neg, pos;
    assign neg = 16'h8000;
    assign pos = 16'h7fff;

    assign b_in = mode ? ~b : b;
    carry_lookahead_4bit cla0(.a(a[3:0]), .b(b_in[3:0]), .cin(mode), .sum(CLASum[3:0]), .cout(c0_1), .mode(1'b0));
    carry_lookahead_4bit cla1(.a(a[7:4]), .b(b_in[7:4]), .cin(c0_1), .sum(CLASum[7:4]), .cout(c1_2), .mode(1'b0));
    carry_lookahead_4bit cla2(.a(a[11:8]), .b(b_in[11:8]), .cin(c1_2), .sum(CLASum[11:8]), .cout(c2_3), .mode(1'b0));
    carry_lookahead_4bit cla3(.a(a[15:12]), .b(b_in[15:12]), .cin(c2_3), .sum(CLASum[15:12]), .cout(c3_4), .mode(1'b0));

    // check if arithmetic operation is saturated
    assign sum = (a[15] & b_in[15] & ~CLASum[15]) ? neg : 
                 ((~a[15] & ~b_in[15] & CLASum[15]) ? pos : CLASum);
    assign overflow = (a[15] & b_in[15] & ~CLASum[15]) | (~a[15] & ~b_in[15] & CLASum[15]);
endmodule