//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_PLAINTEXTREADER_H
#define OMNIREADER_PLAINTEXTREADER_H

#include <cstdio>
#include <cstring>

#include "omnibase.h"



class PlainTextReader : public OmniReader {
private:
    FILE* fp;
public:
    PlainTextReader() : OmniReader(), fp(NULL) {}

    bool open(const char* fname) {
      FILE* tmp = fopen(fname, "rb");
      if (tmp == NULL)
        return false;

      fp = tmp;
      return (refill_page() != 0);
    }

    inline unsigned long long refill_page() {
      unsigned long long used = page_ptr - page;
      unsigned long long unused = page_occupancy - page_ptr;

      history += used;

      memmove(page, page_ptr, unused);

      unsigned long long amount = fread(page, 1, (page_end - page) - unused, fp);
      page[amount] = '\0';
      page_ptr = page;
      page_occupancy = page + amount;

      return amount;
    }

    void rewind() {
      ::rewind(fp);

      history = 0;
      page_ptr = page;
      page_occupancy = page;

      refill_page();
    }
};


#endif //OMNIREADER_PLAINTEXTREADER_H
