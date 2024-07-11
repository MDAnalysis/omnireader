//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_PLAINTEXTREADER_H
#define OMNIREADER_PLAINTEXTREADER_H

#include <cstdio>
#include <cstring>

#include "omnireader.h"



class PlainTextReader final : public OmniReader::Reader {
private:
    FILE* fp;
public:
    PlainTextReader() : Reader(), fp(nullptr) {}

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
      fill_page(0);
      next_ptr = page;
      advance();

      return !at_eof();
    }

    inline unsigned long long fill_page(unsigned long long remainder) final {
      unsigned long long amount = fread(page + remainder, 1, PAGESIZE - remainder, fp);

      page_occupancy = page + remainder + amount;

      return amount;
    }

    bool rewind() final {
      ::rewind(fp);

      history = 0;
      fill_page(0);
      next_ptr = page;
      return advance();
    }
};


#endif //OMNIREADER_PLAINTEXTREADER_H
