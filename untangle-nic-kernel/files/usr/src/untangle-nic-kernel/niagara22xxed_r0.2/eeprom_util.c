/*******************************************************************************

*******************************************************************************/

/*
 * Sample test app to control niagara22xx bypass feature
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <linux/unistd.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <sys/types.h>
#include <fcntl.h>
typedef __uint32_t uint32_t;	/* hack, so we can include driver files */
typedef __uint16_t uint16_t;	/* ditto */
typedef __uint8_t uint8_t;	/* ditto */
#include "n22xx_data.h"
#include "n22xx_cmd.h"

#include <unistd.h>
//extern char *optarg;
//extern int optopt, optind, opterr;

#define SYSCALL(X,S) { if((X) < 0) { perror(S); return -1; } }
#define FILEPART(S)  ( rindex((S), '/') == NULL ? (S) : rindex((S), '/') + 1 )

#define N22XX_BASE_SIOC    (SIOCDEVPRIVATE + 10)

// pic register map

#if 1

const char *type;

uint16_t eeprom_buf[64];

enum
{
  ADDR_OPTION = 0,
  DATA_OPTION,
  MAC_H_OPTION,
  MAC_L_OPTION,
  THE_END
};

#endif

static int
n22xx_eeprom_dump (int fd, struct n22xx_data *data)
{
  int i;

  for (i = 0; i < 64; i++) {
    data->p_addr = i;
    ioctl (fd, N22XX_READ_EEPROM, data, N22XX_BASE_SIOC);

    if (i % 8 == 0) {
      printf ("\n[0x%x]\t0x%x", i, data->p_data);
    }
    else {
      printf ("\t0x%x", data->p_data);
    }
    eeprom_buf[i] = data->p_data;
  }
  printf ("\n");

  return N22XX_STAT_OK;
}

static void
usage (char *name)
{
  fprintf (stderr, "\nUsage: %s  [Slot Number]", name);
  fprintf (stderr, "\nexample :\t./%s 1 \n", name);
}

int
main (int argc, char *argv[])
{
  int fd, output_fd, pair = 0;
  struct n22xx_data test_data;
  int retval = 0;
  char fileName[30];

  fd = open ("/dev/n22xxe", O_RDWR, 0);

  if (fd < 0) {
    printf ("opened failed\n");
    exit (1);
  }
  else {
    /* check how many n22xx is installed */
    test_data.status = N22XX_STAT_OK;
    test_data.cmd = N22XX_UPDATE_MAX_PAIR_NUM;
    ioctl (fd, N22XX_UPDATE_MAX_PAIR_NUM, &test_data, N22XX_BASE_SIOC);
  }

  /* Make sure at least the interface name was given on the 
   * command line */
  if (argc < 2) {
    usage (FILEPART (argv[0]));
    return -1;
  }

  /* get pair number */
  pair = atoi (argv[1]);
  if ((pair < test_data.max_pair_num) && (pair >= 0)) {
    test_data.pair_num = pair;
  }
  else {
    printf
      ("\nPair # greater than the max_number_of pair installed in the system.\n");
    test_data.pair_num = 0;	// use default
  }

  printf ("dev = %d\n", test_data.pair_num);
  n22xx_eeprom_dump (fd, &test_data);
  close (fd);

  // more option
  if (argc > 2) {
    if (strcmp (argv[2], "-o") == 0) {
      if (argv[3] != NULL) {
	strcpy (fileName, argv[3]);
      }
      else {
	strcpy (fileName, "output.bin");
      }
      printf ("\nOutput binary file : %s\n", fileName);

      if ((output_fd = open (fileName, O_RDWR | O_CREAT, 0)) > 0) {
	write (output_fd, eeprom_buf, sizeof (uint16_t) * 64);
	close (output_fd);
      }
      else {
	printf ("Fail to create or open output file!\n");
      }

    }
  }
  return retval;
}
