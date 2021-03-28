#ifndef OMNIREADER_OMNIBASE_H
#define OMNIREADER_OMNIBASE_H

#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <string>

#define PAGESIZE 4194304

class OmniReader {
protected:
    char page[PAGESIZE];  // where data is stored
    char* page_ptr;  // current head onto data
    char* page_occupancy;  // size of data stored
    char* page_end;  // end of work buffer
    unsigned long long history; // total bytes not in page that we've progressed past
    bool eof;  // is file active?
    std::string nextline;  // next line ready to go
    void prepare_next();  // get the next line ready, sets EOF
    unsigned long long refill_page();

public:
    OmniReader() : page(), page_ptr(page), page_occupancy(page), page_end(page + PAGESIZE), history(0), eof(true) {
      memset(page, '\0', PAGESIZE);
      nextline.reserve(255);
    }
    virtual ~OmniReader() = default;

    virtual bool open(const char* fname) = 0;
    std::string getline();
    bool at_eof() const { return nextline.empty(); };
    void seek(unsigned long long, unsigned char);
    virtual void rewind() = 0;
    unsigned long long tell() { return history + (page_ptr - page); };
private:
    virtual inline unsigned long long fill_page() = 0;
};
#endif //OMNIREADER_OMNIBASE_H
