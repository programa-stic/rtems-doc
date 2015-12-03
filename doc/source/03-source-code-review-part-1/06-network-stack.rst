Manejo de Redes
===============

Implementado en ``cpukit/libnetworking``, a partir de un *snapshot* del código del *FreeBSD networking* (la última fecha reportada del *snapshot* es de 1998). Dentro de ese directorio se creó la carpeta ``rtems`` que parecería ser la API visible del *stack*, haciendo de interfaz entre las funciones de POSIX y el *kernel* del *stack* de FreeBSD (con funciones como ``socket`` y ``recvfrom``).

La documentación sobre el manejo de redes no se encuentra en la "*C User's Guide*" sino en el documento "RTEMS Network Supplement" (http://docs.rtems.org/doc-current/share/rtems/html/networking/).

Hay un ejemplo de su utilización en ``testsuites/samples/loopback``. Otros componentes que lo utilizan son el NFS,  STFP, RPC, FTPD, HTTPD, PPPD.


Socket
------

La creación de un socket respeta la API POSIX:

.. code-block:: c

	s = socket(AF_INET, SOCK_STREAM, 0);

Pero su definición no se encuentra en ``libcsupport``, sino dentro del directorio de *networking* ``cpukit/libnetworking/rtems/rtems_syscall.c``:

.. code-block:: c

	/*
	 *********************************************************************
	 *                       BSD-style entry points                      *
	 *********************************************************************
	 */
	int
	socket (int domain, int type, int protocol)
	{
		int fd;
		int error;
		struct socket *so;

		rtems_bsdnet_semaphore_obtain ();
		error = socreate(domain, &so, type, protocol, NULL);
		if (error == 0) {
			fd = rtems_bsdnet_makeFdForSocket (so);
			if (fd < 0)
				soclose (so);
		}
		else {
			errno = error;
			fd = -1;
		}
		rtems_bsdnet_semaphore_release ();
		return fd;
	}

Esta API de RTEMS luego llama a la verdadera implementación en el *kernel* del *networking stack*, en ``cpukit/libnetworking/kern/uipc_socket.c``:

.. code-block:: c

	/*
	 * Socket operation routines.
	 * These routines are called by the routines in
	 * sys_socket.c or from a system process, and
	 * implement the semantics of socket operations by
	 * switching out to the protocol specific routines.
	 */
	/*ARGSUSED*/
	int
	socreate(int dom, struct socket **aso, int type, int proto,
	    struct proc *p)
	{
		register struct protosw *prp;
		register struct socket *so;
		register int error;

		if (proto)
			prp = pffindproto(dom, proto, type);
		else
			prp = pffindtype(dom, type);
		if (prp == 0 || prp->pr_usrreqs == 0)
			return (EPROTONOSUPPORT);
		if (prp->pr_type != type)
			return (EPROTOTYPE);
		MALLOC(so, struct socket *, sizeof(*so), M_SOCKET, M_WAIT);
		bzero((caddr_t)so, sizeof(*so));
		TAILQ_INIT(&so->so_incomp);
		TAILQ_INIT(&so->so_comp);
		so->so_type = type;
		so->so_state = SS_PRIV;
		so->so_uid = 0;
		so->so_proto = prp;
		error = (*prp->pr_usrreqs->pru_attach)(so, proto);
		if (error) {
			so->so_state |= SS_NOFDREF;
			sofree(so);
			return (error);
		}
		*aso = so;
		return (0);
	}


Read
----

Funciones como ``read``/``write`` (lectura/escritura) del *socket* utilizan la  API POSIX, que como se describe en la sección del manejo de archivos, son solo envoltorios que ejecutan el handler de lectura/escritura de la estructura ``rtems_libio_t``, obtenida a partir del *file descriptor* (descriptor de archivo) que se le pasa como parámetro:

.. code-block:: c

	/*
	 *  rtems_libio_iop
	 *
	 *  Macro to return the file descriptor pointer.
	 */

	#define rtems_libio_iop(_fd) \
	  ((((uint32_t)(_fd)) < rtems_libio_number_iops) ? \
	         &rtems_libio_iops[_fd] : 0)


Los *handlers* (manejadores) en este caso estan definidos en ``cpukit/libnetworking/rtems/rtems_syscall.c``:

.. code-block:: c

	static const rtems_filesystem_file_handlers_r socket_handlers = {
		.open_h = rtems_filesystem_default_open,
		.close_h = rtems_bsdnet_close,
		.read_h = rtems_bsdnet_read,
		.write_h = rtems_bsdnet_write,
		.ioctl_h = rtems_bsdnet_ioctl,
		.lseek_h = rtems_filesystem_default_lseek,
		.fstat_h = rtems_bsdnet_fstat,
		.ftruncate_h = rtems_filesystem_default_ftruncate,
		.fsync_h = rtems_filesystem_default_fsync_or_fdatasync,
		.fdatasync_h = rtems_filesystem_default_fsync_or_fdatasync,
		.fcntl_h = rtems_bsdnet_fcntl,
		.kqfilter_h = rtems_filesystem_default_kqfilter,
		.poll_h = rtems_filesystem_default_poll,
		.readv_h = rtems_filesystem_default_readv,
		.writev_h = rtems_filesystem_default_writev
	};

A su vez el *handler* de la función ``read`` (como el de ``write``) terminan llamando a operaciones de *networking* como ``recv``.

.. code-block:: c

	static ssize_t
	rtems_bsdnet_read (rtems_libio_t *iop, void *buffer, size_t count)
	{
		return recv (iop->data0, buffer, count, 0);
	}

	ssize_t
	recv(
		int s,
		void *buf,
		size_t len,
		int flags )
	{
		return (recvfrom(s, buf, len, flags, NULL, 0));
	}

	/*
	 * Receive a message from a host
	 */
	ssize_t
	recvfrom (int s, void *buf, size_t buflen, int flags, const struct sockaddr *from, int *fromlen)
	{
		struct msghdr msg;
		struct iovec iov;
		int ret;

		...

		ret = recvmsg (s, &msg, flags);
		if ((from != NULL) && (fromlen != NULL) && (ret >= 0))
			*fromlen = msg.msg_namelen;
		return ret;
	}

	/*
	 * All `receive' operations end up calling this routine.
	 */
	ssize_t
	recvmsg (int s, struct msghdr *mp, int flags)
	{
		int ret = -1;
		int error;
		struct uio auio;
		struct iovec *iov;

		...
