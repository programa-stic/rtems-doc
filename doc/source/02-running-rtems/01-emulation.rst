Emulación de RTEMS
==================

El objetivo es tener el ambiente de desarrollo completo que permita correr
RTEMS en la máquina de desarrollo (en este caso un Ubuntu).

Para esto se utilizaron dos plataformas principalmente:

* QEMU: El ejemplo para x86 está explicado en el :ref:`documento de instalación de RTEMS <qemu-emulation>`. También se trató de utilizar el QEMU para ARM (arquitectura de interés) aunque no se pudo lograr que funcione (que de todas formas se deja documentado).

* GDB: Tiene un emulador interno de CPU para ARM (entre otras arquitecturas) que permitió emular (aunque en forma limitada) RTEMS en ARM.

Estas emulaciones fueron finalmente descartadas una vez que se pudo instalar y
depurar eficientemente el RTEMS en una RPi (plataforma recomendada sobre los
emuladores).

RTEMS sobre QEMU
================

x86
---

La emulación sobre x86 está documentada en
:ref:`Instalación del Entorno de Desarrollo de RTEMS <qemu-emulation>`. Sin
embargo, este tema no se profundizó porque la arquitectura de interés es ARM.

ARM
---

A diferenca de QEMU sobre x86, en ARM no se pudo instalar GRUB
(para iniciar RTEMS de manera similar a x86). Se intentó utilizar el
*bootloader* U-Boot sin éxito. A continuación, se dejan documentados los pasos
realizados.

Aunque se consiguió cargar exitosamente algunos BSP, en ninguno se logró
imprimir el texto del ejemplo ``hello.exe``.

Los siguientes pasos se basaron en el siguiente tutorial:

* http://www.opensourceforu.com/2011/08/qemu-for-embedded-systems-development-part-2/
* http://www.opensourceforu.com/2011/08/qemu-for-embedded-systems-development-part-3/

Luego de compilar U-Boot (para Ubuntu) se ejecutaron los comandos:

.. code-block:: bash

    arm-rtems4.11-objcopy -Obinary \
        $HOME/development/rtems/bsps/b-rpi/arm-rtems4.11/c/raspberrypi/\
        testsuites/samples/hello/hello.exe hello.bin
    mkimage -A arm -O rtems -T kernel -C none -a 0x00008000 -e 0x00008000 \
        -n "RTEMS Application" -d hello.bin hello.img
    printf "0x%X" $(expr $(stat -c%s u-boot.bin) + 65536)
    cat u-boot.bin hello.img > flash.bin
    qemu-system-arm -M versatilepb -cpu arm1176 -kernel flash.bin -nographic

El comando ``mkimage`` se encuentra dentro del directorio ``tools``, donde se
compiló U-Boot.

El comando ``printf`` da el tamaño del *bootloader* (para el caso de U-Boot
1.2.0 es ``0x217C0``), necesario para saber donde comienza la imagen de RTEMS
(de modo de poder cargarlo). Una vez iniciado U-Boot, se debe ingresar el
comando ``bootm`` con la dirección de la imagen del RTEMS, en el caso de
ejemplo:

.. code-block:: bash

    bootm 0x217C0

Aunque se logra ejecutar inicialmente RTEMS y se puede conectar GDB a QEMU
(como en x86) por distintos inconvenientes nunca se pudo hacer funcionar el
programa de ejemplo ``hello.exe``.


RTEMS en GDB
============

GDB permite emular ARM de manera de poder ejecutar y depurar RTEMS, todo
dentro del mismo GDB.

El BSP que se utilizó fue ``arm920`` que usa ARMv4T, una arquitectura bastante
más antigua que la de, por ejemplo, Raspberry Pi, así que hay que monitorear
las diferencias en el ASM. Por otro lado, no se logró realizar la emulación
con el BSP de Raspberry Pi (nunca llegaba a ejecutar ``Init``, la función
principal de RTEMS).

Dentro de GDB, se debe ejecutar:

.. code-block:: bash

    arm-rtems4.11-gdb hello.exe
    target sim
    load
    run

Donde ``hello.exe`` es el ejecutable del ejemplo generado para el BSP
mencionado antes. No se investigó en profundidad hasta qué punta emula todas
las caracterísitcas del procesador.
