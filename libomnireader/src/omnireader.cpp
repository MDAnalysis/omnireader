#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <iostream>

#include "omnireader.h"

namespace OmniReader {
    bool Reader::advance() {
      // 1) sets line_ptr to the start of the next line
      if (next_ptr == nullptr) {
          // if we've hit the end of the road, move the line ptr to final byte
          line_ptr = page_occupancy;
          eof = true;
          return false;
      }
      line_ptr = next_ptr;

      // 2) sets next_ptr to the start of the one after that
      auto *nextl = (char *) memchr(line_ptr, '\n', page_occupancy - line_ptr);
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
      eof = false;

      return true;
    }

    /**
     * Refills the page buffer maintaining everything from line_ptr forwards
     *
     * @return the number of new bytes read
     */
    unsigned long long Reader::refill_page() {
      unsigned long long remainder = page_occupancy - line_ptr;
      history += line_ptr - page;
      if (remainder) {
          // panic ye not, this is allowed to overlap
          memmove(page, line_ptr, remainder);
      }

      unsigned long long amount = fill_page(remainder);
      page[amount + remainder] = '\0';
      line_ptr = page;

      return amount;
    }

    bool Reader::seek(unsigned long long where, unsigned char whence) {
      // seeks to *where* and this is used as the current line start
      // always SEEK_SET for now
      if (whence != SEEK_SET)
        abort();

      // 1) set next_ptr to the desired address
      // 2) call advance to then set line_ptr to this and prep the next line
      if (where == tell()) {
          // todo: this branch is a bit stupid? could do return at_eof()
        next_ptr = line_ptr;
      }
      else if (where < tell()) {
          unsigned long long buffer_start = history;
          if (buffer_start >= where) {
              // desired address is within buffer behind line_ptr
              next_ptr = page + (where - history);
          } else {
              // desired address is behind us, need to rewind for now...
              rewind();
          }
      }
      // don't make this an else-if, we might be entering from a rewind
      if (where < tell()) {
          unsigned long long buffer_end = history + (page_occupancy - page);
          while (buffer_end < where) {
              // load next page
              line_ptr = page_occupancy;
              unsigned long long newbytes = refill_page();
              if (!newbytes) {
                  // end of file state, both line and next are nullptr
                  line_ptr = nullptr;
                  next_ptr = nullptr;
                  return false;
              }

              buffer_end = history + (page_occupancy - page);
          }
          next_ptr = page + (where - history);
      }

      return advance();
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