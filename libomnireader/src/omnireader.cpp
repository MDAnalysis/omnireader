#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <iostream>

#include "omnireader.h"

namespace OmniReader {
    bool Reader::advance() {
      // 1) sets line_ptr to the start of the next line
      line_ptr = next_ptr;
      if (line_ptr == nullptr) {
          // there was no future line
          return false;
      }

      // 2) sets next_ptr to the start of the one after that
      char *nextl = (char *) memchr(line_ptr, '\n', page_occupancy - line_ptr);
      if (nextl == nullptr) {
        // if we didn't find the next line, shunt back remaining contents
        refill_page();

        nextl = (char *) memchr(line_ptr, '\n', page_occupancy - line_ptr);
      }
      // nextl is either NULL or start of next line
      if (nextl != nullptr) { // only advance on hit
        next_ptr = nextl + 1;
      } else {
        next_ptr = nullptr;
      }

      return true;
    }

    unsigned long long Reader::refill_page() {
      unsigned long long remainder = page_occupancy - line_ptr;

      history += (page_occupancy - page) - remainder;
      // panic ye not, this is allowed to overlap
      if (remainder) {
          unsigned long long next_ptr_offset = next_ptr - line_ptr;
          memmove(page, line_ptr, remainder);
          line_ptr = page;
          next_ptr = line_ptr + next_ptr_offset;
      }

      unsigned long long amount = fill_page(remainder);
      page[amount + remainder] = '\0';

      return amount;
    }

    void Reader::seek(unsigned long long where, unsigned char whence) {
      // seeks to *where* and this is used as the current line start
      // always SEEK_SET for now
      if (whence != SEEK_SET)
        abort();

      if (where == tell())
        return;

      if (where < tell() && where >= history) {
        // lies within current page
        next_ptr = page + (where - history);
      } else {
        if (where < tell())
          rewind();
        // seek forward to victory!
        while (!at_eof()) {
          unsigned long long end = history + (page_occupancy - page);
          if (where < end) {
            line_ptr = page + (where - history);
            break;
          }
          line_ptr = page_occupancy;
          refill_page();
        }
      }

      advance();
    }
}

#include "PlainTextReader.h"
#include "BZ2Reader.h"
#include "GZReader.h"

namespace OmniReader {
    Reader *GetReader(OmniReader::Format option) {
      switch (option) {
        case OmniReader::Format::PlainText:
          return new PlainTextReader();
        case OmniReader::Format::BZ2:
          return new BZ2Reader();
        case OmniReader::Format::GZ:
          return new GZReader();
        default:
          return nullptr;
      }
    }
}