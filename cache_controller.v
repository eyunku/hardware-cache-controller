`include "cla.v"
`include "dff.v"

module cache_fill_FSM(clk, rst_n, miss_detected, miss_address, fsm_busy, write_data_array, write_tag_array, memory_address, memory_data, memory_data_valid);
    // cache capacity: 2KB, memory: 64KB, block size: 16 bytes
    // data transfer granularity: 2-byte words, memory access latency: 4 cycles
    // write-through policy, stall on miss until whole cache block is brought into cache
    
    input clk, rst_n;
    input miss_detected; // active high when tag match logic detects a miss
    input [15:0] miss_address; // address that missed the cache
    output fsm_busy; // asserted while FSM is busy handling the miss (can be used as pipeline stall signal)
    output write_data_array; // write enable to cache data array to signal when filling with memory_data
    output write_tag_array; // write enable to cache tag array to signal when all words are filled in to data array
    output [15:0] memory_address; // address to read from memory
    input [15:0] memory_data; // data returned by memory (after delay)
    input memory_data_valid; // active high indicates valid data returning on memory bus

    // FSM states: Idle, Wait
    wire fsm_busy_w; // idling on 0, waiting on 1
    wire[3:0] offset_out, offset_in; // offset value; output and input into dff
    wire[15:0] offset_16bit;
    assign offset_16bit = {12'h000, offset_out};
    // flip states when idling & miss detected OR waiting & all chunks received
    dff fsm_state(.q(fsm_busy_w), .d(~fsm_busy_w), .wen((miss_detected & ~fsm_busy_w) | ((offset_16bit | 16'h000e) & fsm_busy_w)), .clk(clk), .rst(~rst_n));
    assign fsm_busy = fsm_busy_w;
    
    // read new block whenever miss detected and not busy (strip b-bits)
    wire[15:0] block_start_w;
    dff_16bit block_start(.q(block_start_w), .d(miss_address & 16'hfff0), .wen(miss_detected & ~fsm_busy_w), .clk(clk), .rst(~rst_n));

    // Wait state
    dff_4bit offset(.q(offset_out), .d(offset_in), .wen(memory_data_valid), .clk(clk), .rst(~rst_n)); // update when data received from memory
    carry_lookahead_4bit offset_adder(.a(offset_out), .b(4'h2), .cin(1'b0), .sum(offset_in), .cout(), .mode(1'b0));
    carry_lookahead memory_address_adder(.a(offset_16bit), .b(block_start_w), .sum(memory_address), .overflow(), .mode(1'b0));

    // assign data array/tag array
    assign write_data_array = memory_data_valid;
    assign write_tag_array = (offset_16bit | 16'h000e);
endmodule