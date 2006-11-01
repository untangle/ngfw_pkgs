/*
 * Test image functions. 
 */

#include "../include/gocr.h"
#include "../include/gocr_module.h"

int main (int argc, char **argv) {
  gocr_init(argc, argv);

  gocr_setAttribute(VERBOSE, (void *)3);
  gocr_imageLoad("small.pbm", (void *)GOCR_BW);
  gocr_printArea(currentimage, 0, 0, currentimage->width-1, currentimage->height-1);
  gocr_imageClose();
  gocr_finalize();
  return 0;
}
