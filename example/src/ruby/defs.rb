R0 = 0
R1 = 1
R2 = 2
R3 = 3
R4 = 4
R5 = 5
R6 = 6
R7 = 7
R8 = 8
R9 = 9
R10 = 10
R11 = 11
R12 = 12

SP_REG = 13
LR_REG = 14
PC_REG = 15

COND_EQ = (0b0000 << 28)
COND_NE = (0b0001 << 28)
COND_CS = (0b0010 << 28)
COND_CC = (0b0011 << 28)
COND_MI = (0b0100 << 28)
COND_PL = (0b0101 << 28)
COND_VS = (0b0110 << 28)
COND_VC = (0b0111 << 28)
COND_HI = (0b1000 << 28)
COND_LS = (0b1001 << 28)
COND_GE = (0b1010 << 28)
COND_LT = (0b1011 << 28)
COND_GT = (0b1100 << 28)
COND_LE = (0b1101 << 28)
COND_AL = (0b1110 << 28)

OP_AND = (0b0000 << 21)
OP_EOR = (0b0001 << 21)
OP_SUB = (0b0010 << 21)
OP_RSB = (0b0011 << 21)
OP_ADD = (0b0100 << 21)
OP_ADC = (0b0101 << 21)
OP_SBC = (0b0110 << 21)
OP_RSC = (0b0111 << 21)
OP_TST = (0b1000 << 21)
OP_TEQ = (0b1001 << 21)
OP_CMP = (0b1010 << 21)
OP_CMN = (0b1011 << 21)
OP_ORR = (0b1100 << 21)
OP_MOV = (0b1101 << 21)
OP_BIC = (0b1110 << 21)
OP_MVN = (0b1111 << 21)

SH_LSL = (0b00 << 5)
SH_LSR = (0b01 << 5)
SH_ASR = (0b10 << 5)
SH_ROR = (0b11 << 5)
SH_RRX = (0b11 << 5) # ROR o RRX depende del shift_imm

# Direcciones aproximadas del inicio y final de la sección .text (utilizadas en el findFunctionsAddress)
TEXT_START = 0x8000
TEXT_END = 0x30000
