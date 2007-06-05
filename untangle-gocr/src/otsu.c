/*
 the following code was send by Ryan Dibble <dibbler@umich.edu>
 
  The algorithm is very simple but works good hopefully.
 
  Compare the grayscale histogram with a mass density diagram:
  I think the algorithm is a kind of
  divide a body into two parts in a way that the mass 
  centers have the largest distance from each other,
  the function is weighted in a way that same masses have a advantage
  
  - otsu algorithm is failing on diskrete multi color images
  
  TODO:
    RGB: do the same with all colors (CMYG?) seperately 

    test: hardest case = two colors
       bbg: test done, using a two color gray file. Output:
       # OTSU: thresholdValue = 43 gmin=43 gmax=188

 my changes:
   - float -> double
   - debug option added (vvv & 1..2)
   - **image => *image,  &image[i][1] => &image[i*cols+1]
   - do only count pixels near contrast regions
     this makes otsu much better for shadowed fonts or multi colored text 
     on white background

 (m) Joerg Schulenburg (see README for email address)

 ToDo:
   - measure contrast
   - detect low-contrast regions

 */

#include <stdio.h>
#include <string.h>

#define Abs(x) ((x<0)?-(x):x)

/*======================================================================*/
/* OTSU global thresholding routine                                     */
/*   takes a 2D unsigned char array pointer, number of rows, and        */
/*   number of cols in the array. returns the value of the threshold    */
/*======================================================================*/
int
otsu (unsigned char *image, int rows, int cols, int x0, int y0, int dx, int dy, int vvv) {

  unsigned char *np;    // pointer to position in the image we are working with
  unsigned char op=0;   // predecessor of pixel *np (start value)
  int maxc=0;           // maximum contrast (start value) 
  int thresholdValue=1; // value we will threshold at
  int ihist[256];       // image histogram

  int i, j, k;          // various counters
  int n, n1, n2, gmin, gmax;
  double m1, m2, sum, csum, fmax, sb;

  // zero out histogram ...
  memset(ihist, 0, sizeof(ihist));

  gmin=255; gmax=0; k=dy/512+1;
  // generate the histogram
  // Aug06 images with large white or black homogeneous
  //   areas give bad results, so we only add pixels on contrast edges
  for (i =  0; i <  dy ; i+=k) {
    np = &image[(y0+i)*cols+x0];
    for (j = 0; j < dx ; j++) {
      if (Abs(*np-op)>maxc/8) ihist[*np]++; // count only relevant pixels
      if(*np > gmax) gmax=*np;
      if(*np < gmin) gmin=*np;
      if (Abs(*np-op)>maxc) maxc=Abs(*np-op); /* new maximum contrast */
      /* we hope that maxc will be find its maximum very fast */
      op=*np;     /* store old pixel for contrast check */
      np++;       /* next pixel */
    }
  }

  // set up everything
  sum = csum = 0.0;
  n = 0;

  for (k = 0; k <= 255; k++) {
    sum += (double) k * (double) ihist[k];  /* x*f(x) mass moment */
    n   += ihist[k];                        /*  f(x)    mass      */
    // Debug: output to out_hist.dat?
    // fprintf(stderr,"\nhistogram %3d %6d (brightness weight)", k, ihist[k]);
  }

  if (!n) {
    // if n has no value we have problems...
    fprintf (stderr, "NOT NORMAL, thresholdValue = 160\n");
    return (160);
  }

  // ToDo: only care about extremas in a 3 pixel environment
  //       check if there are more than 2 mass centers (more colors)
  //       return object colors and color radius instead of threshold value
  //        also the reagion, where colored objects are found
  //       what if more than one background color? no otsu at all?
  //       whats background? box with lot of other boxes in it
  //       threshold each box (examples/invers.png,colors.png) 
  //  get maximum white and minimum black pixel color (possible range)
  //    check range between them for low..high contrast ???
  // typical scenes (which must be covered): 
  //    - white page with text of different colors (gray values)
  //    - binear page: background (gray=1) + black text (gray=0)
  //    - text mixed with big (dark) images
  //  ToDo: recursive clustering for maximum multipol moments?
  //  idea: normalize ihist to max=1024 before otsu?
  
  // do the otsu global thresholding method

  fmax = -1.0;
  n1 = 0;
  for (k = 0; k < 255; k++) {
    n1 += ihist[k];          // left  mass (integration)
    if (!n1) { continue; }   // we need at least one foreground pixel
    n2 = n - n1;             // right mass (num pixels - left mass)
    if (n2 == 0) { break; }  // we need at least one background pixel
    csum += (double) k *ihist[k];  // left mass moment
    m1 =        csum  / n1;        // left  mass center (black chars)
    m2 = (sum - csum) / n2;        // right mass center (white background)
    // max. dipol moment?
    // orig: sb = (double) n1 *(double) n2 * (m1 - m2) * (m1 - m2);
    sb = (double) n1 *(double) n2 * (m2 - m1); // seems to be better Aug06
    /* bbg: note: can be optimized. */
    if (sb > fmax) {
      fmax = sb;
      thresholdValue = k + 1;
      // thresholdValue = (m1 + 3 * m2) / 4;
    }
    if ((vvv&1) && ihist[k]) // Debug
     fprintf(stderr,"# OTSU: %3d %6d %6.2f %6.2f %13.0f\n",k,ihist[k],m1,m2,sb);
  }

  // at this point we have our thresholding value
  // black_char: value<cs,  white_background: value>=cs
  
  // can it happen? check for sureness
  if (thresholdValue >  gmax) {
    fprintf(stderr,"# OTSU: thresholdValue >gmax\n");
    thresholdValue = gmax;
  }
  if (thresholdValue <= gmin) {
    fprintf(stderr,"# OTSU: thresholdValue<=gmin\n");
    thresholdValue = gmin+1;
  }

  // debug code to display thresholding values
  if ( vvv & 1 )
  fprintf(stderr,"# OTSU: thresholdValue = %d gmin=%d gmax=%d cmax=%d\n",
     thresholdValue, gmin, gmax, maxc);

  return(thresholdValue);
}

/*======================================================================*/
/* thresholding the image  (set threshold to 128+32=160=0xA0)           */
/*   now we have a fixed thresholdValue good to recognize on gray image */
/*   - so lower bits can used for other things (bad design?)            */
/* ToDo: different foreground colors, gray on black/white background    */
/*======================================================================*/
int
thresholding (unsigned char *image, int rows, int cols, int x0, int y0, int dx, int dy, int thresholdValue) {

  unsigned char *np;    // pointer to position in the image we are working with

  int i, j;          // various counters
  int gmin=255,gmax=0;
  int nmin=255,nmax=0;

  // calculate min/max (twice?)
  for (i = y0 + 1; i < y0 + dy - 1; i++) {
    np = &image[i*cols+x0+1];
    for (j = x0 + 1; j < x0 + dx - 1; j++) {
      if(*np > gmax) gmax=*np;
      if(*np < gmin) gmin=*np;
      np++; /* next pixel */
    }
  }
  
  if (thresholdValue<gmin || thresholdValue>=gmax){
    thresholdValue=(gmin+gmax)/2;
    fprintf(stderr,"# thresholdValue out of range %d..%d, reset to %d\n",
     gmin, gmax, thresholdValue);
  }

  /* b/w: min=0,tresh=0,max=1 */
  // actually performs the thresholding of the image...
  //  later: grayvalues should also be used, only rescaling threshold=160=0xA0
  for (i = y0; i < y0+dy; i++) {
    np = &image[i*cols+x0];
    for (j = x0; j < x0+dx; j++) {
      *np = (unsigned char) (*np > thresholdValue ?
         (255-(gmax - *np)* 80/(gmax - thresholdValue + 1)) :
         (  0+(*np - gmin)*150/(thresholdValue - gmin + 1)) );
      if(*np > nmax) nmax=*np;
      if(*np < nmin) nmin=*np;
      np++;
    }
  }

  // fprintf(stderr,"# OTSU: thresholding  nmin=%d nmax=%d\n", nmin, nmax);

  return(128+32); // return the new normalized threshold value
}

