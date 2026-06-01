Problem - Copy Block Machine Instruction

 

start from stackprocessor pdf, design an instruction copy block – scpb.

User stack constants destination address, source address and number of data to copy, for example,

sc    dest_addr     sc   source_addr    sc   number_of_data   scpb

The scpb pops - number_of_data, source address and destination address, expects on the stack.

Delivery --

    User logic – stack processor 101 with scpb added.
    Simulation for correctness
    IP packaging of sp101
    Testbench, test application and proof or correctness