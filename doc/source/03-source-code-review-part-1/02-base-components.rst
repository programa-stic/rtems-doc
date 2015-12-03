Capa de Abstracción del *Hardware*
==================================

Módulo CPU
----------

Este componente responde al código que está en el directorio
``c/src/lib/libcpu``. Contiene funcionalidades que son **dependientes**
del modelo de CPU pero no del *board* utilizado.

Hay una capa común a todas las arquitecturas que está en
``c/src/lib/libcpu/shared`` y que contiene funcionalidades de *cache*.

En el caso concreto de i386 provee las siguientes funcionalidades:

* Funcionalidades para habilitar y deshabilitar la *cache*.
* Funcionalidades para acceder a registros de segmentos.
* Funcionalidades para acceder puertos de E/S.
* Funcionalidades para dar de alta segmentos (interfaz con la GDT).
* Funcionalidades para manejo básico de los mecanísmos de paginación.
* Funcionalidades para manejo las interrupciones (usa funciones que están en ``score/cpu/i386/rtems/score/interrupts.h``).

En otras arquitecturas, como es el caso de ARM, hay otro tipo de
funcionalidades implementadas, por ejemplo, *Clock* y *Timer*. Esto es
así pues son soportadas por el CPU (y no el *board*). En cambio, esto no
sucede con i386 donde el *Timer* está dado por el controlador 8254
(*Programmable Interval Timer*) que está en el *board*, por lo tanto,
esta funcionalidad se encuentra implementada dentro de
``c/src/lib/libbsp``. Algo similar ocurre con el *Clock*. En este caso,
está dado por el controlador MC146818A (*Real-Time Clock Plus Ram (RTC)*).
Por lo tanto, esta funcionalidad se encuentra en el BSP.

.. note::

    El código que interactúa con el CPU pareciera estar disperso en, al
    menos, 2 directorios. Además, del código que está en directorio
    ``c/src/lib/libcpu``, hay código en el directorio
    ``cpukit/score/cpu``. Existe interacción entre ambos como se ve en
    la definiciones de interrupciones para la arquitectura i386.

Módulo BSP
----------

Este componente responde al código que está en el directorio
``c/src/lib/libbsp``. Contiene funcionalidades que interactúan con el *board*.
Por ejemplo, hay *drivers* de *Clock*, *Timer*, *Ethernet*, *Console*, *IDE*,
etc. Todos ellos **independientes** del modelo de CPU.

.. note::

    En ``c/src/lib/libbsp/i386/pc386/startup`` hay código para bootear
    el procesador y, además, está el *script* del *linker* (``linkcmds``) usado
    para *linkear* RTEMS.
