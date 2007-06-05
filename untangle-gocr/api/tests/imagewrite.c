/*
 * Test gocr_mainImageWriteWithData, addBlock.
 */

#include "../include/gocr.h"
#include "../include/gocr_module.h"

int main (int argc, char **argv) {
  gocr_Block b;
  gocr_init(argc, argv);

  gocr_setAttribute(VERBOSE, (void *)3);
  gocr_imageLoad("small.pbm", (void *)GOCR_BW);

  b.x0 = b.y0 = 1;
  b.x1 = currentimage->width-2;
  b.y1 = currentimage->height-2;
  b.t = gocr_blockTypeGetByName("TEXT");
  gocr_blockAdd(&b);
  gocr_printBlock(&b);

  gocr_mainImageWriteWithData("imagewrite.ppm");
  gocr_finalize();
  return 0;
}
