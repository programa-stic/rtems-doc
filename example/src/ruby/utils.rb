require '~/rtems/rtems-project/security/exploitation/agent/src/ruby/defs.rb'


def in32range (v)
    (v >= 0 and v <= 0xFFFFFFFF)
end

def is32aligned (v)
    in32range(v) and v % 4 == 0
end

def validRegNum (ri)
    ri >= 0 and ri <= 15
end

def payload2Str (p)
    #p.to_s(16)
    s = ''
    p.each { |c| s << "\\x%02x" % c}
    s
#    s = "".join("\\x{:02x}".format(c) for c in p)
#    return s
end

def pack32bitsLittleEndian (i)
    [i].pack("<L*").bytes.to_a
end

def printPayload (p)
    puts(payload2Str(p))
end

def twosComplement(x)
  fail unless x < 0
  fail unless (-x) <= 0x80000000
  x = (0xFFFFFFFF + x + 1)
  fail(x.to_s) unless x >= 0x80000000 # si es mas bajo que este numero fallo y el x quedo positivo
  return x
end

def genBranch(pc, targetAddress, condition = COND_AL, linkBranch = false)
  fail unless is32aligned(pc)
  fail unless is32aligned(targetAddress)
  fail unless ((targetAddress >= 0) and (targetAddress <= 0xFFFFFFFF))

  i = condition
  i |= (0b101 << 25)
  i |= (1 << 24) if linkBranch

  # Se siguen las indicaciones del ARM Architecture Reference Manual (pag A4-11) para calcular la distancia del branch
  baseAddress = pc + 8
  byteOffset = targetAddress - baseAddress
  fail unless byteOffset % 4 == 0
  fail unless ((byteOffset >= -33554432) and (byteOffset <= +33554428))
  # if byteOffset < 0
  #   byteOffset = twosComplement(byteOffset)  # Innecesario porque ruby en binario interpreta Fixnum como 2's complement
  # end
  signed_immed_24 = (byteOffset & ("1" * 26).to_i(2)) >> 2  # Se extraen los bits [25:2] del byte offset

  i |= signed_immed_24

  return i
end

def genBL (pc, target)
  return genBranch(pc, target, COND_AL, linkBranch = true)
end

# BLX y BX
def genBranchToReg(rm, condition = COND_AL, linkBranch = false)
  fail unless validRegNum(rm)

  i = condition
  i |= (0b00010010 << 20)
  i |= (0b111111111111 << 8) # SBO según la documentación
  i |= (0b0001 << 4)

  # Aunque no vi que la documentación lo aclare explícitamente la única diferencia visible entre BX y BLX es este bit
  i |= (1 << 5) if linkBranch

  i |= rm

  return i
end

# Rd = [Rn + Imm]
def genLdrImm (rd, rn, imm)
    fail unless validRegNum(rd) and validRegNum(rn)
    fail unless imm >= 0 and imm <= 0xFFF
    i = 0xe5900000 # e: cond = always, 5: I = 0/P = 1, 9: UBWL = 1001
    i |= (rd << 12)
    i |= (rn << 16)
    i |= imm
    
    return i
end

def genLoadStoreImmediate(rd, rn, imm, p_bit, u_bit, b_bit, w_bit, l_bit)
  fail unless validRegNum(rd) and validRegNum(rn)
  fail unless imm >= 0 and imm <= 0xFFF
  i = 0
  i |= 0xe << 28      # e: cond = always
  i |= 0b01 << 26
  i |= 0b0 << 25      # I = 0: (immediate addressing)
  i |= p_bit << 24    # P = 0: (post-indexed), P = 1: (offset or pre-indexed)
  i |= u_bit << 23    # U = 0: (base - address), U = 1: (base + address)
  i |= b_bit << 22    # B = 0: (word), B = 1: (byte)
  i |= w_bit << 21    # With P = 1 -> W = 0 (offset), W = 1 (pre-indexed)
  i |= l_bit << 20    # L = 1: (Load), L = 0 (Store)
  i |= (rd << 12)
  i |= (rn << 16)
  i |= imm

  return i
end

# Rd = [Rn + Imm]; Rn += Imm
def genLoadPostIndexed(rd, rn, imm)
  return genLoadStoreImmediate(rd, rn, imm, 0, 1, 0, 0, 1)
end

# [Rn + Imm] = Rd; Rn += Imm
def genStorePostIndexed(rd, rn, imm)
  return genLoadStoreImmediate(rd, rn, imm, 0, 1, 0, 0, 0)
end

def genLoadStoreScaledRegOffset(rd, rn, rm, shift_imm, shift, p_bit, u_bit, b_bit, w_bit, l_bit, cond = COND_AL)
  fail unless validRegNum(rd) and validRegNum(rn) and validRegNum(rm)
  fail unless shift_imm >= 0 and shift_imm <= 32 # aunque según el tipo de shift hay valores inválidos que no checkeo
  i = 0
  i |= cond
  i |= 0b01 << 26
  i |= 0b1 << 25      # I = 1: (register addressing)
  i |= p_bit << 24    # P = 0: (post-indexed), P = 1: (offset or pre-indexed)
  i |= u_bit << 23    # U = 0: (base - address), U = 1: (base + address)
  i |= b_bit << 22    # B = 0: (word), B = 1: (byte)
  i |= w_bit << 21    # With P = 1 -> W = 0 (offset), W = 1 (pre-indexed)
  i |= l_bit << 20    # L = 1: (Load), L = 0 (Store)
  i |= (rn << 16)
  i |= (rd << 12)
  i |= (shift_imm << 7)
  i |= shift
  i |= rm

  return i
end

def genLoadStoreMultiple(rn, p_bit, u_bit, s_bit, w_bit, l_bit, regList, cond = COND_AL)
  fail unless validRegNum(rn)

  i = cond
  i |= 0b100 << 25
  i |= p_bit << 24    # P = 0: (Rn is included in the range of memory), P = 1: (Rn is not included)
  i |= u_bit << 23    # U = 0: (upwards from the base register), U = 1: (downwards)
  i |= s_bit << 22    # Indicates that the CPSR is loaded from the SPSR
  i |= w_bit << 21    # Indicates that the base register is updated after the transfer
  i |= l_bit << 20    # L = 1: (Load), L = 0: (Store)
  i |= (rn << 16)

  regList.each do |ri|
    fail unless validRegNum(ri)
    i |= (1 << ri)
  end

  return i
end

# PUSH = STMDB = STMFD (Full Descending)
def genPush(regList)
  return genLoadStoreMultiple(rn = SP_REG, p_bit = 1, u_bit = 0, s_bit = 0, w_bit = 1, l_bit = 0, regList, cond = COND_AL)
end

# POP = LDMIA = LDMFD (Full Descending)
# Se invierten los bits L/P/U con respecto al PUSH
def genPop(regList)
  return genLoadStoreMultiple(rn = SP_REG, p_bit = 0, u_bit = 1, s_bit = 0, w_bit = 1, l_bit = 1, regList, cond = COND_AL)
end

# Usa el 32-bit immediate addressing mode
#TODO: agregar el 4-bit rotate para el immediate
def genDataProc32bitImm(rd, rn, imm, opCode, updateFlags = false, cond = COND_AL)
  fail unless validRegNum(rd) and validRegNum(rn)
  fail unless imm >= 0 and imm <= 0xFF

  i = cond
  i |= (0b001 << 25) # bit (25) I = 1 (32-bit immediate addressing mode)
  i |= opCode
  i |= (1 << 20) if updateFlags
  i |= (rn << 16)
  i |= (rd << 12)
  i |= imm

  return i
end

# Usa el immediate shift (en vez de un 32-bit immediate de arriba)
def genDataProcImmShift(rd, rn, rm, shift_imm, shift, opCode, updateFlags = false, cond = COND_AL)
  fail unless validRegNum(rd) and validRegNum(rn) and validRegNum(rm)
  fail unless shift_imm >= 0 and shift_imm <= 32 # aunque según el tipo de shift hay valores inválidos que no checkeo

  i = cond
  i |= (0b000 << 25) # bit (25) I = 0 (Immediate shift)
  i |= opCode
  i |= (1 << 20) if updateFlags
  i |= (rn << 16)
  i |= (rd << 12)
  i |= (shift_imm << 7)
  i |= shift
  i |= rm

  return i
end

# Rd = Imm
def genMovReg (rd, imm)
  return genDataProc32bitImm(rd, rn = R0, imm, opCode = OP_MOV) # Rn no se usa para esta operación
end

# Rd = Rn + Imm
def genAddImm (rd, rn, imm, updateFlags = false)
    return genDataProc32bitImm(rd, rn, imm, opCode = OP_ADD, updateFlags)
end

# Rd = Rn - Imm
def genSubImm (rd, rn, imm, updateFlags = false)
    return genDataProc32bitImm(rd, rn, imm, opCode = OP_SUB, updateFlags)
end

# Rn - Imm -> Flags
def genCmpImm(rn, imm)
    return genDataProc32bitImm(0, rn, imm, OP_CMP, true, COND_AL)
end

# Rn - Rm -> Flags
def genCmpReg(rn, rm)
    return genDataProcImmShift(0, rn, rm, 0, SH_LSL, OP_CMP, true, COND_AL)
end

# Rd = Rm
def genMovRegToReg(rd, rm)
    return genDataProcImmShift(rd, 0, rm, 0, SH_LSL, OP_MOV, false, COND_AL)
end

# Obtengo PC en base al tamaño del payload generado hasta ahora
def getPc (bufAddress, payload)
    fail unless is32aligned(bufAddress)
    fail unless len(payload) % 4 == 0
    return bufAddress + payload.length
end

# Redondea al prox multiplo m del numero x
def upToMult (x, m)
    fail unless x > 0 and m > 0
    return m * (x.to_i / m.to_f).ceil
end
