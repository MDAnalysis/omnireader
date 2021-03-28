#include <cstdio>
#include <cstring>

#include "omnireader.h"

namespace OmniReader {
    void Reader::prepare_next() {
      nextline.clear();
      if (page_ptr == nullptr) {
        return;
      }

      char *nextl = (char *) memchr(page_ptr, '\n', page_occupancy - page_ptr);
      if (nextl == nullptr) {
        nextline.append(page_ptr, page_occupancy - page_ptr);
        refill_page();
        nextl = (char *) memchr(page_ptr, '\n', page_occupancy - page_ptr);
      }
      // nextl is either NULL or start of next line
      if (nextl != nullptr) { // only advance on hit
        nextline.append(page_ptr, nextl + 1 - page_ptr);
        page_ptr = nextl + 1;
      } else {
        page_ptr = nullptr;
      }
    }

    std::string Reader::getline() {
      if (!at_eof()) {
        std::string ret(nextline);
        nextline.clear();
        prepare_next();

        return ret;
      } else
        return std::string();
    }

    unsigned long long Reader::refill_page() {
      history += page_occupancy - page;

      unsigned long long amount = fill_page();

      eof = (amount == 0);
      page[amount] = '\0';
      page_ptr = page;
      page_occupancy = page + amount;

      return amount;
    }

    void Reader::seek(unsigned long long where, unsigned char whence) {
      // always SEEK_SET for now
      if (whence != SEEK_SET)
        abort();

      if (where == tell())
        return;

      if (where < tell() && where >= history) {
        // lies within current page
        page_ptr = page + (where - history);
      } else {
        if (where < tell())
          rewind();
        // seek forward to victory!
        while (!at_eof()) {
          unsigned long long end = tell() + (page_occupancy - page_ptr);
          if (where < end) {
            page_ptr = page + (where - history);
            break;
          }
          refill_page();
        }
      }
      prepare_next();
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