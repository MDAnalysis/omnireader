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

      eof = false;
      prepare_next();

      return !at_eof();
    }

    unsigned long long fill_page() final {
      unsigned long long amount = gzread(gzfp, page, (page_end - page));

      return amount;
    }

    void rewind() final {
      gzrewind(gzfp);

      history = 0;
      page_ptr = page;
      page_occupancy = page;

      refill_page();
    }
};

#endif //OMNIREADER_GZREADER_H
