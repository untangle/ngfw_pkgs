/*
 * Test module functions. 
 * Note: this assumes that you have a specific module in a specific directory, 
 *with specific function names. Change it to suit your setup.
 */

#include "../include/gocr.h"
#include "../include/gocr_module.h"
#include "../include/gocr_char.h"
#include <ltdl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* this is hack, disregard */
void none( void ) {
	gocr_Box *b; wchar_t w; float prob;
	gocr_boxCharSet(b, w, prob);
}

int main (int argc, char **argv) {
	gocr_ModuleId		m;
	char *x;

 LTDL_SET_PRELOADED_SYMBOLS();

	if (gocr_init(argc, argv) != 0) {
		printf("Could not init gocr\n");
		exit(1);
	}

	gocr_setAttribute(VERBOSE, (void *)3);
	
	/* modules */
	if ( (m = gocr_moduleLoad("/home/gocr/modules/modules/libtester.la")) == -1 ) {
		fprintf(stderr, "You should get the mdk tester at gocr's homepage.\n"
				"If you already have it, edit module.c and make sure the"
				"path is correct.\n");
		exit(2);
	}
	gocr_functionAppend("test_imageFilter", m, NULL);
	gocr_functionAppend("test_blockFinder", m, NULL);
	gocr_functionAppend("test_charFinder", m, NULL);
	gocr_functionAppend("test_charRecognizer", m, NULL);
	gocr_functionAppend("test_contextCorrection", m, NULL);
	gocr_functionAppend("test_outputFormatter", m, NULL);

	gocr_imageLoad("small.pbm", (void *)GOCR_BW);
	gocr_runAllModules();

	gocr_mainImageWriteWithData("module.ppm");
	gocr_imageClose();
	gocr_finalize();
	return 0;
}

