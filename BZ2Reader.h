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
    BZ2Reader() : OmniReader(), fp(nullptr), bzfp(nullptr) {};

    ~BZ2Reader() {
      int error;
      if (bzfp)
        BZ2_bzReadClose(&error, bzfp);
      if (fp)
        fclose(fp);
    }

    bool open(const char* fname) final {
      int error;
      FILE* tmp;
      tmp = fopen(fname, "r");
      if (!tmp) {
        fprintf(stderr, "Failed with stdio fhandle\n");
        return false;
      }
      fp = tmp;

      bzfp = BZ2_bzReadOpen(&error, fp, 0, 0, nullptr, 0);
      if (error != BZ_OK) {
        fprintf(stderr, "Failed bzReadOpen\n");
        return false;
      }

      eof = false;
      prepare_next();

      return !at_eof();
    }

    inline unsigned long long fill_page() final {
      int error;
      unsigned int amount = BZ2_bzRead(&error, bzfp, page, (int)(page_end - page));
      // TODO: Deal with error codes

      return amount;
    }

    void rewind() final {
      int error;
      BZ2_bzReadClose(&error, bzfp);
      ::rewind(fp);
      bzfp = BZ2_bzReadOpen(&error, fp, 0, 0, nullptr, 0);

      history = 0;
      page_ptr = page;
      page_occupancy = page;

      refill_page();
    }
};

#endif //OMNIREADER_BZ2READER_H
