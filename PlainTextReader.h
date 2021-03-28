//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_PLAINTEXTREADER_H
#define OMNIREADER_PLAINTEXTREADER_H

#include <cstdio>
#include <cstring>

#include "omnibase.h"



class PlainTextReader final : public OmniReader {
private:
    FILE* fp;
public:
    PlainTextReader() : OmniReader(), fp(nullptr) {}

    ~PlainTextReader() final {
      if (fp != nullptr)
        fclose(fp);
    }

    bool open(const char* fname) final {
      FILE* tmp = fopen(fname, "rb");
      if (tmp == nullptr) {
        fprintf(stderr, "Error: Failed to open file: %s\n", fname);
        return false;
      }

      fp = tmp;
      eof = false;
      refill_page();
      prepare_next();

      return !at_eof();
    }

    inline unsigned long long fill_page() final {
      unsigned long long amount = fread(page, 1, (page_end - page), fp);

      return amount;
    }

    void rewind() final {
      ::rewind(fp);

      history = 0;
      page_ptr = page;
      page_occupancy = page;
      eof = false;
      refill_page();
    }
};


#endif //OMNIREADER_PLAINTEXTREADER_H
