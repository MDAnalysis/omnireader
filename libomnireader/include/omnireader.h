//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_OMNIREADER_H
#define OMNIREADER_OMNIREADER_H

#include <string>
#include <cstring>

namespace OmniReader {

    enum Format {
        PlainText = 0,
        BZ2 = 1,
        GZ = 2,
    };

#define PAGESIZE 4194304
    class Reader {
    public:
        Reader() : page(), line_ptr(nullptr), next_ptr(page), page_occupancy(nullptr), history(0) {
          memset(page, 0xFF, PAGESIZE);
        }
        virtual ~Reader() = default;
        // Returns success on opening a file
        virtual bool open(const char *fname) = 0;
        // Returns copy of next line and advances reader
        const char* line_start() const { return line_ptr; };
        const char* line_end() const { return next_ptr == nullptr ? page_occupancy : next_ptr - 1; };
        std::string get_line() const { return std::string(line_start(), line_end()); }
        bool advance();
        // Is a line available?
        inline bool at_eof() const { return line_ptr == nullptr; };
        // Reposition reader, curerntly only SEEK_SET allowed
        void seek(unsigned long long, unsigned char);
        // Reposition reader to start of file
        virtual void rewind() = 0;
        // Current position of reader
        unsigned long long tell() const { return history + (line_ptr - page) ; };

    protected:
        char page[PAGESIZE];  // where data is stored
        char *line_ptr;  // points to current line, within page
        char *next_ptr;  // points to start of next line, within page
        char *page_occupancy;  // size of data stored
        unsigned long long history; // total bytes not in page that we've progressed past
        void prepare_next();  // get the next line ready, sets EOF
        unsigned long long refill_page();
        virtual inline unsigned long long fill_page(unsigned long long remainder) = 0;
    };

    Reader *GetReader(Format option);
}

#endif //OMNIREADER_OMNIREADER_H
