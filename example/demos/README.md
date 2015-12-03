# README

# Ejemplos de payloads

En esta carpeta se encuentran ejemplos básicos de payloads para probar el framework de desarrollo.

Dado que el único hardware donde se pudo probar RTEMS es la Raspberry Pi, cuyo port no tiene habilitado los drivers de la red todo se realiza por comunicación serie.

Las pruebas están orientadas a la funcionalidad del *payload*, no a la explotació de RTEMS en sí, del cual no se tiene ningún programa ejemplo por ahora.

Los ejemplos tienen dos lados, el programa de RTEMS (`receivePayload.c`) basado en el ejemplo de `hello.exe` que básicamente espera recibir datos por el puerto serie, los carga a un *buffer* y los ejecuta como una función (simulando un *buffer overflow*), y del otro lado ejemplos en Ruby (`sendPayload.rb`) que seleccionan alguno de los *payloads* generados y los envia por serie para ser ejectados por RTEMS.

La versión de Ruby utilizada es 1.9.3 (debe ser mayora a la 1.8.x que trae está en los paquetes de Ubuntu sino el código no va a funcionar, particularmente por el uso de la directiva `require_relative` que no está soportada en versiones anteriores).

# RTEMS

Como no se investigó como crear y compilar satisfactoriamente programas separados, siempre se trabaja sobre el `init.c` del ejemplo `hello.exe` y se compila este. Por tanto para poder utilizar `receivePayload.c` hay que vincularlo a init.c\` (o sobreescribir los contenidos de un archivo con otro).

En este archivo se encuentra la función `vulnFunc` que es la función que simula tener la vulnerabilidad donde se carga y se ejecuta el *payload* enviado por serie.

La comunicación serie, del lado de RTEMS se realiza mediante la función `readBytes` que recibe tramas con el formato:

> (Preludio) "AAAA" | DATA\_LEN | DATA | CHECKSUM |

Se recomienda no modificar este archivo dado que los ejemplos tienen varias direcciones fijas escritas a mano, que de modificarse el archivo podrían variar y causar un error en los ejemplos.

# Atacante

Del lado del atacante se realizaron ejemplos en Ruby que usan el *framework* para generar *payloads* ubicado en `../src/ruby/`.

El archivo `sendPayload.rb` envía el *payload* del ejemplo seleccionado (mediante la directiva `require`).

El archivo `listen.rb` monitorea el puerto serie y guarda todo lo recibido en el archivo `serial.log`.

# Ejemplos


## `pthreadPayload.rb`

Este payload es el caso clásico de crear un *thread* de ejecución aparte para no interferir con la ejecución principal. Se separa en dos etapas:

-   La etapa-0 lee por serie (único canal disponible) la etapa-1, crea un *thread* para ejecutarla y retorna a la ejecución principal.
-   La etapa-1 recorre la memoria para buscar las funciones que va a necesitar (fingerprints.rb) y luego se queda esperando a recibir direcciones de funciones a ejecutar junto a sus parámetros.

## `evt_irq_corruption.rb`

Este payload se separa en dos etapas, la primera modifica el handler el IRQ y lo apunta a una dirección de memoria donde espera que se envie la segunda etapa donde lo copia, esta segunda etapa simplemente maneja un contador que al llegar a 10000 interrupciones escribe un mensaje. Este ejemplo puede fallar porque no es lo ideal llamar a un puts en medio de una interrupción.

# Correr un ejemplo

Se supone que se tiene un RTEMS corriendo en una RPi y se usa otra RPi para realizar la interfaz entre JTAG y GDB, como se describe en la documentación.

Para la comunicacioń serie se utlizó el chip CP2102 que realiza la conversión entre la interfaz serie del UART de la RPi y un puerto USB para conectar a la computadora de desarrollo. El resultado es un puerto serie en la dirección `/dev/ttyUSB0` (puede variar el número y la dirección según el OS), al que se conecta la PC de desarrollo.

Primer se comienza monitoreando la comunicación serie con el archivo `listen.rb
sudo ruby listen.rb
```

En otra consola se recomienda estar viendo el log con el comando `tail -f serial.log`.

Se conecta el GDB a la RPi de depuración, que contiene el OpenOCD, con el comando:

```bash
arm-rtems4.11-gdb $HOME/development/rtems/build-rtems-rpi/arm-rtems4.11/c/raspberrypi/testsuites/samples/hello/hello.exe
target remote <ip_rpi>:3333
```

Se supone que se está utilizando el ejemplo de `hello.exe` para realizar la pruebas, sino será otra la dirección especificada del ejecutable a depurar. La IP `<ip_rpi>` corresponde a la IP de la RPi donde se corre OpenOCD, el puerto 3333 es el que utiliza por defecto OpenOCD pero se puede cambiar en la configuración.

Una vez conectado se carga y corre el ejemplo, con los comandos de GDB:

```bash
load
continue
```

Si el programa se cargó correctamente se verá una salida similar a:

```bash
Loading section .start, size 0x1e4 lma 0x8000
Loading section .text, size 0x19314 lma 0x81e8
Loading section .init, size 0x18 lma 0x214fc
Loading section .fini, size 0x18 lma 0x21514
Loading section .rodata, size 0x1488 lma 0x100000
Loading section .ARM.exidx, size 0x8 lma 0x101488
Loading section .eh_frame, size 0x48 lma 0x101490
Loading section .init_array, size 0x4 lma 0x1014d8
Loading section .fini_array, size 0x4 lma 0x1014dc
Loading section .jcr, size 0x4 lma 0x1014e0
Loading section .data, size 0x610 lma 0x1014e8
Start address 0x8040, load size 110620
Transfer rate: 6 KB/sec, 2989 bytes/write.
```

Por el puerto serie, monitoreado por el programa en Ruby aparecerá:

```bash
*** START VULN ***
```

Indicando que se llegó correctamente a la función vulnerable y se está esperando por el puerto serie que se envíe el *paylaod* a ejecutar.

A veces falla la primera carga del programa y es necesario volverlo a cargar nuevamente (no se pudo determinar exactamente la razón).

Una forma de verificar si el programa falló por alguna razón indeterminada es frenar la ejecución del programa en GDB y ver si está en la funcíón `_Terminate`, y corriendo el comando `backtrace` ver si fue llamada por la función `rtems_fatal` que es la forma más común que tiene RTEMS de terminar la ejecución (quedándose corriendo un loop infinito) en caso de algún error.

```bash
Program received signal SIGINT, Interrupt.
0x0001089c in _Terminate (the_source=the_source@entry=RTEMS_FATAL_SOURCE_EXCEPTION, is_internal=is_internal@entry=false, the_error=3852464152)
    at ../../../../../../rtems-git/c/src/../../cpukit/score/src/interr.c:52
52    _CPU_Fatal_halt( the_error );
(gdb) backtrace
#0  0x0001089c in _Terminate (the_source=the_source@entry=RTEMS_FATAL_SOURCE_EXCEPTION, is_internal=is_internal@entry=false, the_error=3852464152)
    at ../../../../../../rtems-git/c/src/../../cpukit/score/src/interr.c:52
#1  0x0000f96c in rtems_fatal (source=source@entry=RTEMS_FATAL_SOURCE_EXCEPTION, error=<optimized out>)
    at ../../../../../../rtems-git/c/src/../../cpukit/sapi/src/fatal2.c:34
#2  0x000159cc in _ARM_Exception_default (frame=<optimized out>)
    at ../../../../../../../../rtems-git/c/src/../../cpukit/score/cpu/arm/arm-exception-default.c:24
#3  0x00013504 in save_more_context () at ../../../../../../../../rtems-git/c/src/../../cpukit/score/cpu/arm/armv4-exception-default.S:142
Backtrace stopped: previous frame identical to this frame (corrupt stack?)
```

De no fallar se envia el *payload* con el comando:

```bash
sudo ruby sendPayload.rb
```

En este caso se dejó seleccionado el ejemplo `pthreadPayload.rb` dentro del archivo `sendPayload.rb`, en las primeras líneas:

``` {.sourceCode .ruby}
# Seleccionar uno de los payloads y comentar el resto

require_relative "pthreadPaylaod"
# require_relative "evt_irq_corruption"
```

Mostrará la salida:

```bash
Enviando etapa-0
Enviado
Enviando etapa-1
Enviado
Presionar Enter para enviar RPC
```

Indicando que se enviaron las dos etapas del payload del ejemplo. El programa de RTEMS monitoreado por `listen.rb`, de recibir correctamente los datos mostrará la salida:

```bash
*** START VULN ***
LEYO EL PREAMBULO!!
Leyo el len: 56
Se leyeron todos los datos: 56 bytes
LEYO EL PREAMBULO!!
Leyo el len: 476
Byte 100/476
Byte 200/476
Byte 300/476
Byte 400/476


*** END VULN ***
mainThread!
Preparado para ejecutar funcion.
mainThread!
mainThread!
mainThread!
mainThread!
LEYO EL PREAMBULO!!
Leyo el len: 20
Preparado para ejecutar funcion.
mainThread!
mainThread!
mainThread!
LEYO EL PREAMBULO!!
Leyo el len: 20
mainThread!
Preparado para ejecutar funcion.
mainThread!
mainThread!
```

Lo primero que se ve es el progreso del envio de datos (las dos etapas del *payload*), luego termina la función vulnerable (`*** END VULN ***`), lo que indica que la etapa-0 copió la etapa-1 a memoria y retornó el flujo a la ejecución normal, indicado por la leyenda `mainThread!` que se repite cada 2-3 segundos.

Mientras tanto en paralelo corre el *thread* con la etapa-1 inyectada, que imprime la leyenda `Preparado para ejecutar funcion.` (al haber solo un canal de comunicación todo se imprime por serie).

Al presionar `Enter` en la consola que ejeucta el ataque (`sendPayload.rb`) se envia una función a ejecutar junto con sus parámetros, que es interpretada y ejecutada por la etapa-1 que espera recibir datos por serie (siemrpe mediante la función `readBytes`). Las leyendas `LEYO EL PREAMBULO!!` y `Leyo el len: 20` indican la recepción de los datos de la función a ejecutar. Dado que la función a ejecutar en este ejemplo es simplemente `rtems_task_wake_after`, que solo genera que el *thread* pause su ejeución durante una cierta cantidad de tiempo, sin tener ningún otro efecto perceptible. Sin embargo podemos observar el fin de la ejecución de la función cuando la etapa-1 vuelve a imprimir `Preparado para ejecutar funcion.` esperando la siguiente función a ejecutar.
