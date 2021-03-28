#include <cstdio>
#include <cstring>

#include "omnibase.h"

void OmniReader::prepare_next() {
  if (page_ptr == nullptr) {
    fputs("Ptr was null\n", stderr);
    nextline.clear();
    return;
  }

  char* nextl = (char*) memchr(page_ptr, '\n', page_occupancy - page_ptr);
  if (nextl == nullptr) {
    nextline.append(page_ptr, page_occupancy - page_ptr);
    refill_page();
    nextl = (char*) memchr(page_ptr, '\n', page_occupancy - page_ptr);
  }
  // nextl is either NULL or start of next line
  if (nextl != nullptr) { // only advance on hit
    nextline.append(page_ptr, nextl + 1 - page_ptr);
    page_ptr = nextl + 1;
  }
  else {
    page_ptr = nullptr;
  }
}

std::string OmniReader::getline() {
  if (!at_eof()) {
    std::string ret(nextline);
    nextline.clear();
    prepare_next();

    return ret;
  } else
    return std::string();
}

unsigned long long OmniReader::refill_page() {
  history += page_occupancy - page;

  unsigned long long amount = fill_page();

  eof = (amount == 0);
  page[amount] = '\0';
  page_ptr = page;
  page_occupancy = page + amount;

  return amount;
}


// Peek at at least *amount* bytes, but limited to PAGESIZE
const char* OmniReader::peek(unsigned long long amount) {
  if (amount > (page_occupancy - page_ptr))
    refill_page();
  return page_ptr;
}

void OmniReader::seek(unsigned long long where, unsigned char whence) {
  // always SEEK_SET for now
  if (whence != SEEK_SET)
    abort();

  if (where == tell())
    return;

  // is where behind us?
  if (where < tell()) {
    if (where >= history) {  // lies within current page
      page_ptr = page + (where - history);
      return;
    }
    else
      rewind();
  }
  // seek forward to victory!
  while (!at_eof()) {
    unsigned long long end = tell() + (page_occupancy - page_ptr);
    if (where < end) {
      page_ptr = page + (where - history);
      return;
    }
    refill_page();
  }
}
