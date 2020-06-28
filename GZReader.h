//
// Created by richard on 28/06/2020.
//

#ifndef OMNIREADER_GZREADER_H
#define OMNIREADER_GZREADER_H

#include <zlib.h>

#include "omnibase.h"

class GZReader : public OmniReader {
private:
    gzFile gzfp;
public:
    GZReader() : OmniReader(), gzfp(NULL) {}

    ~GZReader() {
      if (gzfp)
        gzclose(gzfp);
    }

    bool open(const char* fname) {
      gzFile tmp = gzopen(fname, "r");
      if (!tmp)
        return false;
      gzfp = tmp;

      return (refill_page() != 0);
    }

    unsigned long long refill_page() {
      unsigned long long used = page_ptr - page;
      unsigned long long unused = page_occupancy - page_ptr;

      history += used;

      memmove(page, page_ptr, unused);

      unsigned long long amount = gzread(gzfp, page, (page_end - page) - unused);

      page[amount] = '\0';
      page_ptr = page;
      page_occupancy = page + amount;

      return amount;
    }

    void rewind() {
      gzrewind(gzfp);

      history = 0;
      page_ptr = page;
      page_occupancy = page;

      refill_page();
    }
};

#endif //OMNIREADER_GZREADER_H
