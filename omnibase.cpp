#include <cstdio>
#include <cstring>

#include "omnibase.h"

// Return pointer to at least next full line
const char* OmniReader::getline() {
  char* nextl = (char*) memchr(page_ptr, '\n', page_occupancy - page_ptr);
  if (nextl == NULL) {
    refill_page();
    nextl = (char*) memchr(page_ptr, '\n', page_occupancy - page_ptr);
  }
  // nextl is either NULL or start of next line
  char* ret = page_ptr;
  if (nextl != NULL) // only advance on hit
    page_ptr = nextl + 1;

  return ret;
}


// Peek at at least *amount* bytes
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
  bool eof = false;
  while (!eof) {
    unsigned long long end = tell() + (page_occupancy - page_ptr);
    if (where < end) {
      page_ptr = page + (where - history);
      return;
    }
    eof = (refill_page() == 0);
  }
}
