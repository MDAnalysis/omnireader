#ifndef OMNIREADER_OMNIBASE_H
#define OMNIREADER_OMNIBASE_H

#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <string>

#define PAGESIZE 4194304

class OmniReader {
public:
    OmniReader() : page(NULL), page_occupancy(NULL), page_ptr(NULL), page_end(NULL), history(0) {
      char* tmp = (char*) malloc(PAGESIZE + 1);
      if (tmp) {
        page = tmp;
        page_ptr = page;
        page_occupancy = page;
        page_end = page + PAGESIZE;
        memset(page, 0, PAGESIZE + 1);
      }
    }
    ~OmniReader() {
      if (page)
        free(page);
    }
    virtual bool open(const char* fname) = 0;
    const char* getline();
    const char* peek(unsigned long long);
    void seek(unsigned long long, unsigned char);
    virtual void rewind() = 0;
    unsigned long long tell() { return history + (page_ptr - page); };
private:
    virtual inline unsigned long long refill_page() = 0;

protected:
    char* page;
    char* page_ptr;
    char* page_occupancy;
    char* page_end;
    unsigned long long history;

};
#endif //OMNIREADER_OMNIBASE_H
