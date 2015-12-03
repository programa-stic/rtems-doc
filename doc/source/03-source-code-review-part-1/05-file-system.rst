Sistema de Archivos
===================

Se encontraron dos mecanismos de I/O. La API POSIX (``open``, ``read``, ``write``, etc.) que parecería interactuar con el sistema de archivos (*File System*, FS) únicamente, y el I/O Manager (``rtems_io_open``, ``rtems_io_read``, ``rtems_io_write``) para acceder al resto de los dispositivos.

Se supone que ambos mecanismos podrían realizar las mismas acciones y deberían utilizar las mismas librerías (porque en teoría los dispositivos están vinculados al FS, que a su vez se encuentra dentro un dispositivo), pero por ahora no se ha encontrado esta conexión, y se los analiza por separado.

Por lo visto las implementaciones de las dos APIs usan algunos componentes de SuperCore, por ejemplo ``Chains`` (listas).


API POSIX I/O
-------------

Se encuentra en ``cpukit/libcsupport``, distribuido en distintos archivos según las funciones. Estas funciones utilizan *handlers* preconfigurados:

.. code-block:: c

	/*
	*  Now process the read().
	*/
	return (*iop->pathinfo.handlers->read_h)( iop, buffer, count );

La funcionalidad está soportada por la ``cpukit/libfs``, según su *README*, este directorio contiene la librería del sistema de archivos. Todos los sistemas de archivos soportados están en este directorio:

	* IMFS or In Memory File System: "*This is the only root file system on RTEMS at the moment. It supports files, directories, device nodes and mount points. It can also be configured to be the miniIMFS.*"

	* TFTP and FTP filesystem.

	* DEVFS or Device File system.

	* DOSFS, a FAT 12/16/32 MSDOS compatible file system.

	* NFS Client, can mount NFS exported file systems.

	* PIPE, a pipe file system.

	* RFS, The RTEMS File System.


Según el FS, se cargan los *handlers* correspondientes, por ejemplo, para el DOSFS:

.. code-block:: c

	/* msdos_set_handlers --
	 *     Set handlers for the node with specified type(i.e. handlers for file
	 *     or directory).
	 *
	 * PARAMETERS:
	 *     loc - node description
	 *
	 * RETURNS:
	 *     None
	 */
	static void
	msdos_set_handlers(rtems_filesystem_location_info_t *loc)
	{
	    msdos_fs_info_t *fs_info = loc->mt_entry->fs_info;
	    fat_file_fd_t   *fat_fd = loc->node_access;

	    if (fat_fd->fat_file_type == FAT_DIRECTORY)
	        loc->handlers = fs_info->directory_handlers;
	    else
	        loc->handlers = fs_info->file_handlers;
	}


RTEMS I/O Manager
-----------------

Pertence a la API Classic, ubicada en ``cpukit/sapi``. Sus funciones (denominadas *directivas* en el manual de RTEMS) acceden a *device drivers* (manejadores de dispositivos), que debería incluir a los mecanismos del FS descriptos antes aunque no se encontró la conexión.

Este componente utiliza diferentes librerías, dependiendo el *device driver* con el que debe interactuar, por lo que no se lo puede ubicar precisamente en un solo directorio, algunas de las estructuras utilizadas son:

	* ``c/src/libchip``: IDE
	* ``c/src/lib/libbsp``: Console
	* ``cpukit/libmisc/devnull``: ``/dev/null`` y ``/dev/zero``
	* ``cpukit/libblock``: ATA

Los distintos *device drivers* disponibles se especifican en ``cpukit/sapi/include/confdefs.h``. Por ejemplo, para ``rtems_io_open``:

.. code-block:: c

	rtems_status_code rtems_io_open(
	  rtems_device_major_number  major,
	  rtems_device_minor_number  minor,
	  void                      *argument
	)
	{
	  rtems_device_driver_entry callout;

	  callout = _IO_Driver_address_table[major].open_entry;
	  return callout ? callout(major, minor, argument) : RTEMS_SUCCESSFUL;
	}

Según el identificador del *device* (dispositivo, separado en un número mayor y menor) se buscará el *driver* correspondiente en la tabla ``_IO_Driver_address_table``, establecida en ``confdefs.h``:

.. code-block:: c

	typedef struct {
	  rtems_device_driver_entry initialization_entry;
	  rtems_device_driver_entry open_entry;
	  rtems_device_driver_entry close_entry;
	  rtems_device_driver_entry read_entry;
	  rtems_device_driver_entry write_entry;
	  rtems_device_driver_entry control_entry;
	} rtems_driver_address_table;

	rtems_driver_address_table
	_IO_Driver_address_table[ CONFIGURE_MAXIMUM_DRIVERS ] = {
	#ifdef CONFIGURE_BSP_PREREQUISITE_DRIVERS
	  CONFIGURE_BSP_PREREQUISITE_DRIVERS,
	#endif
	#ifdef CONFIGURE_APPLICATION_PREREQUISITE_DRIVERS
	  CONFIGURE_APPLICATION_PREREQUISITE_DRIVERS,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_CONSOLE_DRIVER
	  CONSOLE_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_CLOCK_DRIVER
	  CLOCK_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_RTC_DRIVER
	  RTC_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_WATCHDOG_DRIVER
	  WATCHDOG_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_STUB_DRIVER
	  DEVNULL_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_ZERO_DRIVER
	  DEVZERO_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_IDE_DRIVER
	  IDE_CONTROLLER_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_ATA_DRIVER
	  ATA_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_FRAME_BUFFER_DRIVER
	  FRAME_BUFFER_DRIVER_TABLE_ENTRY,
	#endif
	#ifdef CONFIGURE_APPLICATION_EXTRA_DRIVERS
	  CONFIGURE_APPLICATION_EXTRA_DRIVERS,
	#endif
	#ifdef CONFIGURE_APPLICATION_NEEDS_NULL_DRIVER
	  NULL_DRIVER_TABLE_ENTRY
	#endif
	};

Por ejemplo, para los *drivers* de la consola, se especifican los distintos *handlers* (en este caso en ``c/src/lib/libbsp``):

.. code-block:: c

	/*
	 * We redefine CONSOLE_DRIVER_TABLE_ENTRY to redirect /dev/console
	 */
	#undef CONSOLE_DRIVER_TABLE_ENTRY
	#define CONSOLE_DRIVER_TABLE_ENTRY \
	  { console_initialize, console_open, console_close, \
	      console_read, console_write, console_control }

