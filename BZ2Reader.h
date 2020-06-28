//
// Created by richard on 28/06/2020.
//

#ifndef OMNIREADER_BZ2READER_H
#define OMNIREADER_BZ2READER_H

#include <cstring>
#include <bzlib.h>

#include "omnibase.h"

class BZ2Reader : public OmniReader {
private:
    FILE* fp;
    BZFILE* bzfp;
public:
    BZ2Reader() : OmniReader(), fp(NULL), bzfp(NULL) {};

    ~BZ2Reader() {
      int error;
      if (bzfp)
        BZ2_bzReadClose(&error, bzfp);
      if (fp)
        fclose(fp);
    }

    bool open(const char* fname) {
      int error;
      FILE* tmp;
      tmp = fopen(fname, "r");
      if (!tmp) {
        fprintf(stderr, "Failed with stdio fhandle\n");
        return false;
      }
      fp = tmp;

      bzfp = BZ2_bzReadOpen(&error, fp, 0, 0, NULL, 0);
      if (error != BZ_OK) {
        fprintf(stderr, "Failed bzReadOpen\n");
        return false;
      }

      return (refill_page() != 0);
    }

    inline unsigned long long refill_page() {
      unsigned long long used = page_ptr - page;
      unsigned long long unused = page_occupancy - page_ptr;

      history += used;

      memmove(page, page_ptr, unused);

      int error;
      unsigned int amount = BZ2_bzRead(&error, bzfp, (page + unused), (int)(page_end - page));
      fprintf(stderr, "bzerr: %d\n", error);
      // TODO: Check error, detect EOF early?
      page[amount] = '\0';
      page_ptr = page;
      page_occupancy = page + amount;

      fprintf(stderr, "Got %d bytes\n", amount);

      return amount;
    }

    void rewind() {
      int error;
      BZ2_bzReadClose(&error, bzfp);
      ::rewind(fp);
      bzfp = BZ2_bzReadOpen(&error, fp, 0, 0, NULL, 0);

      history = 0;
      page_ptr = page;
      page_occupancy = page;

      refill_page();
    }
};

#endif //OMNIREADER_BZ2READER_H
