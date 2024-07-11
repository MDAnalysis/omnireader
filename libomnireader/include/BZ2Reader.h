//
// Created by richard on 28/06/2020.
//

#ifndef OMNIREADER_BZ2READER_H
#define OMNIREADER_BZ2READER_H

#include <cstring>
#include <bzlib.h>

#include "omnireader.h"

class BZ2Reader final : public OmniReader::Reader {
private:
    FILE* fp;
    BZFILE* bzfp;
public:
    BZ2Reader() : Reader(), fp(nullptr), bzfp(nullptr) {};

    ~BZ2Reader() final {
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

      fill_page(0);
      next_ptr = page;
      advance();

      return !at_eof();
    }

    inline unsigned long long fill_page(unsigned long long remainder) final {
      int error;
      unsigned int amount = BZ2_bzRead(&error, bzfp, page + remainder, (int)(PAGESIZE- remainder));
      // TODO: Deal with error codes

      page_occupancy = page + remainder + amount;

      return amount;
    }

    bool rewind() final {
      int error;
      BZ2_bzReadClose(&error, bzfp);
      ::rewind(fp);
      bzfp = BZ2_bzReadOpen(&error, fp, 0, 0, nullptr, 0);

      history = 0;
      fill_page(0);
      next_ptr = page;
      return advance();
    }
};

#endif //OMNIREADER_BZ2READER_H
