//
// Created by richard on 28/06/2020.
//

#ifndef OMNIREADER_GZREADER_H
#define OMNIREADER_GZREADER_H

#include <zlib.h>

#include "omnireader.h"

class GZReader final : public OmniReader::Reader {
private:
    gzFile gzfp;
public:
    GZReader() : Reader(), gzfp(nullptr) {}

    ~GZReader() final {
      if (gzfp)
        gzclose(gzfp);
    }

    bool open(const char* fname) final {
      gzFile tmp = gzopen(fname, "r");
      if (!tmp)
        return false;
      gzfp = tmp;

      fill_page(0);
      next_ptr = page;
      advance();

      return !at_eof();
    }

    unsigned long long fill_page(unsigned long long remainder) final {
      unsigned long long amount = gzread(gzfp, page + remainder, PAGESIZE - remainder);

      page_occupancy = page + remainder + amount;

      return amount;
    }

    bool rewind() final {
      gzrewind(gzfp);

      history = 0;

      fill_page(0);
      next_ptr = page;
      return advance();
    }
};

#endif //OMNIREADER_GZREADER_H
