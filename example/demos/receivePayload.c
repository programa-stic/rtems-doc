/*
 *  COPYRIGHT (c) 1989-2012.
 *  On-Line Applications Research Corporation (OAR).
 *
 *  The license and distribution terms for this file may be
 *  found in the file LICENSE in this distribution or at
 *  http://www.rtems.com/license/LICENSE.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <bsp.h> /* for device driver prototypes */

#include <stdio.h>
#include <stdlib.h>

#include <termios.h>

/* forward declarations to avoid warnings */
rtems_task Init(rtems_task_argument argument);

#include <pthread.h>

#define SERIAL_READ_BUF_SIZE 20 * 1024
#define OF_BUF_SIZE 0x10000
#define PREAMBLE_CHAR 'A'
#define PREAMBLE_LEN 4

char serialReadBuffer[SERIAL_READ_BUF_SIZE];

int readByte()
{
	char c;
	int rc = fread(&c, 1, 1, stdin);
	if (rc == 0)
	{
		printf( "ERROR EN readByte, exit.\n" );
//		return -1;
		exit( 0 );
	}
	return c;
}

int readBytes(char *buf)
{
	int checksum, calcChecksum = 0;
	int i;
	int len;

	readPreamble();
	printf("LEYO EL PREAMBULO!!\n");

	len = readInt();
	printf("Leyo el len: %d\n", len);

	if (len > SERIAL_READ_BUF_SIZE)
	{
		printf("El len (%d) es mas grande que el buffer de lectura (%d)\n", len, SERIAL_READ_BUF_SIZE);
		return -1;
	}

	for (i = 0; i < len; i++)
	{
		buf[i] = readByte();
		if ((i + 1) % 100 == 0)
			printf("Byte %d/%d\n", i + 1, len);
		calcChecksum ^= buf[i];
	}
	checksum = readInt();
	if (checksum != calcChecksum)
	{
		printf( "ERROR en readBytes: fallo el checksum.\n" );
		printf( "Esperado: %x. Recibido: %x.", calcChecksum, checksum);
		return -1;
//		exit( 0 );
	}

	return len;
}

void readPreamble()
{
	int preambleCount = 0;

	while (1)
	{
		char c = readByte();
		if (c == PREAMBLE_CHAR)
		{
			preambleCount++;
			if (preambleCount == PREAMBLE_LEN)
				return;
		}
		else
		{
//			printf("FAIL PREAMBuLo, leyo %c (%d)\n", c, c);
			preambleCount = 0;
		}
	}
}

// Little endian
int readInt()
{
	int i, val = 0;
	for (i = 0; i < 4; i++)
	{
		char c = readByte();
		((char *)&val)[i] = c;
	}
	return val;
}

void vulnFunc()
{
	printf( "\n\n*** START VULN ***\n" );

	char overflowBuf[OF_BUF_SIZE];
	int rb;
	int i;


	while (1) {
		rb = readBytes(overflowBuf);

		if (rb == -1) {
			printf("Error en readBytes, salgo...\n");
//			exit (0);
			continue;
		}
		printf("Se leyeron todos los datos: %d bytes\n", rb);
//		for (i = 0; i < rb; i++)
//			printf("%d - ", overflowBuf[i]);
//		printf("\n");


		// No se hace el overflow por ahora, se llama directamente al payload
		void (*callBufFunc) (void) = overflowBuf;

		callBufFunc();

		break;
	}

	printf( "\n\n*** END VULN ***\n" );
}

void*
mainThread(
  void* argument
)
{
  unsigned int id = (unsigned int) argument;
  unsigned int i = 0;

  vulnFunc();

  while (1) {
    printf( "mainThread!\n");
    rtems_task_wake_after(200);
  }
  pthread_exit( NULL );

  return NULL;
}

/*
 * Sacado de testsuites/libtests/termios/
 * Test raw (ICANON=0) input
 */
void configure_raw_input( int vmin, int vtime )
{
  int i;
  struct termios old, new;
  rtems_interval ticksPerSecond, then, now;
  unsigned int msec;
  unsigned long count;
  int nread;
  unsigned char cbuf[100];

  ticksPerSecond = rtems_clock_get_ticks_per_second();
  if ( tcgetattr( fileno ( stdin ), &old ) < 0 ) {
    perror( "configure_raw_input(): tcgetattr() failed" );
    return;
  }

  new = old;
  new.c_lflag &= ~( ICANON | ECHO | ECHONL | ECHOK | ECHOE | ECHOPRT | ECHOCTL );
  new.c_cc[VMIN] = vmin;
  new.c_cc[VTIME] = vtime;
  if( tcsetattr( fileno( stdin ), TCSANOW, &new ) < 0 ) {
    perror ("configure_raw_input(): tcsetattr() failed" );
    exit (1);
  }

  if( tcflush( fileno( stdin ), TCIOFLUSH ) < 0 ) {
    perror ("configure_raw_input(): tcflush() failed" );
    exit (1);
  }
}


rtems_task Init(
  rtems_task_argument ignored
)
{

	configure_raw_input(1, 0);

	pthread_t Thread_id_1;
	pthread_attr_t attr;
	pthread_attr_init(&attr);
//	pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
//	pthread_attr_setschedpolicy(&attr, SCHED_RR);
	pthread_create(&Thread_id_1, &attr, mainThread, (void *) 1);

	pthread_join(Thread_id_1, NULL); // sin el join Init debe tener mas prioridad que el thread porque no lo ejecuta nunca

	while (1) ; // Si el Init termina se apaga RTEMS, asi que hay que dejarlo trabado

}

#define CONFIGURE_MAXIMUM_POSIX_THREADS     10

#define CONFIGURE_APPLICATION_NEEDS_CLOCK_DRIVER

#define CONFIGURE_MICROSECONDS_PER_TICK   1000
#define CONFIGURE_TICKS_PER_TIMESLICE       50

#define CONFIGURE_APPLICATION_NEEDS_CONSOLE_DRIVER

#define CONFIGURE_MAXIMUM_TASKS            10
#define CONFIGURE_USE_DEVFS_AS_BASE_FILESYSTEM

#define CONFIGURE_RTEMS_INIT_TASKS_TABLE

#define CONFIGURE_INIT
#include <rtems/confdefs.h>
