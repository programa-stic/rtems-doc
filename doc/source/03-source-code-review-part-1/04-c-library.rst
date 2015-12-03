Librería de C
=============

Según la documentación de RTEMS la librería de C provista está basada en
Newlib, la misma es descargada por la herramienta *Source Builder* durante
la preparación del ambiente de desarrollo para RTEMS. Esta se compila
estáticamente junto con el resto del sistema operativo. Su código se encuentra en:
``~/development/rtems/src/rtems-source-builder/rtems/sources/cvs/``.

Dependencias
------------

Se estudiaron algunos archivos para ver la dependencia de la librería de C con
SuperCore, la API POSIX y otros componentes.

	* ``malloc``, ``calloc``, ``realloc``, ``free``, ``rtems_heap_``: utilizan el mecanísmo Heap de SuperCore.

	* ``open``, ``close``, ``read``, ``write``, ``lseek``, etc: dependen de los handlers definidos en ``libfs``.
