/*
 * Test gocr_mainImageWriteWithData, addBlock.
 */

#include "../include/gocr.h"
#include "../include/gocr_module.h"
#include "../include/gocr_char.h"
#include "../include/gocr_list.h"
#include "../src/_gocr.h"

int main (int argc, char **argv) {
  gocr_Block block;
 char *p;
  
  if ( gocr_init(argc, argv) != 0 ) {
    printf("Could not init gocr\n");
    exit(1);
  }

  gocr_setAttribute(VERBOSE, (void *)4);
  gocr_imageLoad("small.pbm", (void *)GOCR_BW);

  block.x0 = block.y0 = 0;
  block.x1 = currentimage->width-1;
  block.y1 = currentimage->height-1;
  block.t = gocr_blockTypeGetByName("TEXT");
  gocr_blockAdd(&block);

p = malloc(100);
strcpy(p, "hello");

  currentblock = &block;

  gocr_charBegin();
  gocr_charSetRect(GOCR_SET, 11, 0, 20, 16);
  gocr_charEnd();

  gocr_printBox(currentbox);

  gocr_charBegin();
  gocr_charSetAllNearPixels(GOCR_SET, 4, 9, 4);
  gocr_charEnd();

  gocr_printBox(currentbox);

  gocr_charBegin();
  gocr_charSetAllNearPixels(GOCR_SET, 24, 2, 8);
  gocr_charEnd();

  gocr_printBox(currentbox);

  gocr_mainImageWriteWithData("charfind.ppm");
  gocr_imageClose();
  gocr_finalize();
  return 0;
}
