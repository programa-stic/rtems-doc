Instalación del Entorno de Desarrollo de RTEMS
==============================================

En esta sección se detallan todos los comandos necesarios para instalar el
entorno de desarrollo de RTEMS en una máquina virtual con sistema operativo
*Ubuntu 14.04 (x86_64)* instalado.

.. note::
    Es posible utilizar una VM con todo el ambiente de desarrollo de RTEMS preinstalado, sin embargo, la última fecha de actualizacíón es de noviembre de 2012. La misma se puede descargar de ``http://sourceforge.net/projects/rtems-vms/files/``. Para más información, visitar ``https://devel.rtems.org/wiki/TBR/Delete/Virtual_Machines_for_RTEMS_Development``.

Máquina Virtual
---------------

Para la instalación, se utilizó una máquina virtual con las siguientes
especificaciones:

+--------------------+--------------+
| Sistema Operativo  | Ubuntu 14.04 |
+--------------------+--------------+
| Tipo de Procesador | x86_64       |
+--------------------+--------------+
| # Procesadores     | 2            |
+--------------------+--------------+
| Memoria            | 2048MB       |
+--------------------+--------------+
| Disco Rígido       | 5GB          |
+--------------------+--------------+

Estructura de directorios
-------------------------

Siguiendo los lineamientos del tutorial:

* http://alanstechnotes.blogspot.com.ar/2013/03/setting-up-rtems-development.html

Se definió la siguiente estructura de directorios en la máquina virtual:

* ``~/development/rtems``: Directorio raiz de toda la estructura de desarrollo.

* ``~/development/rtems/src/git``: Repositorio del RTEMS.

* ``~/development/rtems/src/rtems-source-builder``: Repositorio de la herramienta *Source Builder*.

* ``~/development/rtems/qemu``: Archivos varios para la utilización del emulador QEMU.

* ``~/development/rtems/bsps``: Directorio donde se compilan los BSP para distintos *targets* (por ejemplo, ``b-pc386/``, ``b-sis/``, etc).

* ``~/development/rtems/4.11/bin``: Directorio con los ejecutables de la herramientas necesarias para compilar RTEMS.

*Source Builder*
----------------

El *Source Builder*, provisto por RTEMS, automatiza toda la instalación del
entorno de desarrollo necesario para los distintos *targets*. Las
instrucciones para usarlo están en el siguiente *link*:

* https://ftp.rtems.org/pub/rtems/people/chrisj/source-builder/source-builder.html

Estas instrucciones se complementan con otro tutorial para instalar RTEMS
en Raspberry Pi:

* http://alanstechnotes.blogspot.com.ar/2013/03/setting-up-rtems-development.html

Para compilar el *Source Builder* es necesario instalar algunas herramientas
previas:

.. code-block:: bash

    sudo apt-get build-dep binutils gcc g++ gdb unzip git python2.7-dev
    sudo apt-get install binutils gcc g++ gdb unzip git python2.7-dev

Una vez instaladas las herramientas, se debe descargar el *Source Builder* y se
debe comprobar (último comando listado) que el sistema tiene todos los
requisitos necesarios para compilar RTEMS:

.. code-block:: bash

    mkdir -p ~/development/rtems/src
    cd ~/development/rtems/src
    git clone git://git.rtems.org/rtems-source-builder.git
    cd rtems-source-builder
    source-builder/sb-check

La salida esperada de la comprobación debería ser similar a la siguiente:

.. code-block:: bash

    RTEMS Source Builder - Check, v4.11.0
    Environment is ok

*Build Sets*
------------

Para cada *target* (i386, Sparc, etc.) es necesario instalar un conjunto
distinto de herramientas de compilación (denominado *build set*) a través del *Source Builder*.
En este caso se muestra el comando para el *target* i386:

.. code-block:: bash

    cd ~/development/rtems/src/rtems-source-builder/rtems
    ../source-builder/sb-set-builder --log=l-i386.txt \
        --prefix=$HOME/development/rtems/4.11 4.11/rtems-i386

Este comando descargará y compilará todas las herramientas necesarias (gcc,
gdb, newlib, etc.). Tener en cuenta que puede tardar varios minutos (entre 10 y 20
aproximadamente). El flag ``--prefix`` indica dónde serán instaladas y
``4.11/rtems-i386`` indica el *target* deseado. Para conocer los *targets*
soportados se puede ejecutar el siguiente comando:

.. code-block:: bash

    sb-set-builder --list-bsets

Para poder usar las herramientas compiladas es necesario incluirlas a ``PATH``:

.. code-block:: bash

    export PATH=$PATH:$HOME/development/rtems/4.11/bin

De no incluirlas fallarán los pasos de compilación que se detallan a
continuación (para mayor facilidad puede incluirse la modificación a ``PATH``
en el archivo ``.profile`` del usuario actual).

Compilación
-----------

Los siguientes pasos fueron extraídos en parte de los siguiente tutoriales de
RTEMS:

* https://devel.rtems.org/wiki/TBR/UserManual/Quick_Start

Inicialmente se descarga el repositorio de RTEMS y se ejecuta un *script* de
configuración:

.. code-block:: bash

    mkdir -p ~/development/rtems/src/git
    cd ~/development/rtems/src/git
    git clone git://git.rtems.org/rtems.git
    cd rtems
    ./bootstrap

Para compilar un BSP para un *target* particular (suponiendo que ya fueron
instaladas las herramientas de compilación para el *target* elegido, en este
ejemplo i386) se corre un archivo de configuración del RTEMS y se utiliza la
herramienta ``make``. En este ejemplo se agregó el flag ``--enable-rtems-debug``
para luego poder depurar la aplicación:

.. code-block:: bash

    mkdir -p ~/development/rtems/bsps
    cd ~/development/rtems/bsps
    mkdir b-pc386
    cd b-pc386
    ../../src/git/rtems/configure --target=i386-rtems4.11 --enable-rtemsbsp=pc386 \
        --enable-tests=samples --enable-rtems-debug
    make all

.. _qemu-emulation:

QEMU
----

En el caso de compilar para i386 debe utilzarse el emulador QEMU, que **no**
es provisto por el *Source Builder*. Se puede instalar con el siguiente
comando:

.. code-block:: bash

    sudo apt-get install qemu

Además, para cargar RTEMS es necesario un archivo utilizado por QEMU:

.. code-block:: bash

    cd ~/development/rtems/
    mkdir -p ~/development/rtems/qemu
    cd ~/development/rtems/qemu
    cp <rtems-project dir>/misc/pc386_fda .

Donde ``<rtems-project dir>`` es la dirección donde se encuentra el proyecto
de esta documentación.

El archivo ``pc386_fda`` tiene preestablecida la dirección del ejecutable que
debe cargar (``/home/rtems/qemu/hd/test.exe``). Por el momento, por
comodidad, se realiza un *link* a ese *path* con el ejecutable de ejemplo que
se desee depurar (en esta demonstración es el ``hello.exe``):

.. code-block:: bash

    mkdir -p /home/rtems/qemu/hd/
    ln -s ~/development/rtems/bsps/b-pc386/i386-rtems4.11/c/pc386/testsuites/samples/hello/hello.exe \
        /home/rtems/qemu/hd/test.exe

Para cargar el ejecutable y verificar que el proceso de instalación ha sido
exitoso se utiliza QEMU con el siguiente comando:

.. code-block:: bash

    qemu-system-i386 -m 64 -boot a -cpu 486 -fda ~/development/rtems/qemu/pc386_fda \
        -hda fat:/home/rtems/qemu/hd -monitor null -nographic -serial stdio --no-reboot

La salida que debería verse por pantalla es la siguiente:

.. code-block:: bash

    *** HELLO WORLD TEST ***
    Hello World
    *** END OF HELLO WORLD TEST ***

Depuración
----------

Para poder depurar RTEMS es necesario incluir al comando de QEMU los
parámetros ``-s`` (para generar el *debug server* al cual GDB se conectará) y
``-S`` para detener la ejecución en la primera instrucción del programa:

.. code-block:: bash

    qemu-system-i386 -m 64 -boot a -cpu 486 -fda ~/development/rtems/qemu/pc386_fda \
        -hda fat:/home/rtems/qemu/hd -monitor null -nographic -serial stdio --no-reboot -s -S

Esto iniciará RTEMS y lo dejará detenido en la primera ejecución. Para poder
conectarse con GDB se deberá abrir otra consola y ejecutar el comando:

.. code-block:: bash

    i386-rtems4.11-gdb /home/rtems/qemu/hd/test.exe

El cual iniciará la sesión de GDB. Para "conectarse" a RTEMS (que se está
ejecutando), se debe ingresar el siguiente comando de GDB:

.. code-block:: bash

    target remote :1234

Las primeras instrucciones corresponden a la BIOS y no serán reconocidas por
GDB como parte de los fuentes del RTEMS. Se verá el mensaje:

.. code-block:: bash

    0x0000fff0 in ?? ()

De todas maneras puede insertarse un *breakpoint* en la función principal del
programa ``Init`` (que sí es reconocida por GDB):

.. code-block:: bash

    b Init
    c

Luego, se puede verificar que la configuración de GDB es correcta si puede
visualizarse el archivo fuente del ejemplo, para ello se debe ingresar el
siguiente comando de GDB:

.. code-block:: bash

    list *$eip

El cual mostrará el código fuente del ejemplo:

.. code-block:: bash

    (gdb) list *$eip
    0x1001b4 is in Init (../../../../../../../../src/rtems/c/src/../../
        testsuites/samples/hello/init.c:29).
    24  const char rtems_test_name[] = "HELLO WORLD";
    25
    26  rtems_task Init(
    27    rtems_task_argument ignored
    28  )
    29  {
    30    rtems_test_begin();
    31    printf( "Hello World\n" );
    32    rtems_test_end();
    33    exit( 0 );
