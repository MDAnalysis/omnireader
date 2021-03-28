//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_OMNIREADER_H
#define OMNIREADER_OMNIREADER_H

#include <string>

#include <string.h>

namespace OmniReader {

    enum Format {
        PlainText = 0,
        BZ2 = 1,
        GZ = 2,
    };

#define PAGESIZE 4194304
    class Reader {
    protected:
        char page[PAGESIZE];  // where data is stored
        char *page_ptr;  // current head onto data
        char *page_occupancy;  // size of data stored
        char *page_end;  // end of work buffer
        unsigned long long history; // total bytes not in page that we've progressed past
        bool eof;  // is file active?
        std::string nextline;  // next line ready to go
        void prepare_next();  // get the next line ready, sets EOF
        unsigned long long refill_page();

    public:
        Reader() : page(), page_ptr(page), page_occupancy(page), page_end(page + PAGESIZE), history(0), eof(true) {
          memset(page, '\0', PAGESIZE);
          nextline.reserve(255);
        }

        virtual ~Reader() = default;

        virtual bool open(const char *fname) = 0;

        std::string getline();

        bool at_eof() const { return nextline.empty(); };

        void seek(unsigned long long, unsigned char);

        virtual void rewind() = 0;

        unsigned long long tell() { return history + (page_ptr - page); };
    private:
        virtual inline unsigned long long fill_page() = 0;
    };

    Reader *GetReader(Format option);
}

#endif //OMNIREADER_OMNIREADER_H
