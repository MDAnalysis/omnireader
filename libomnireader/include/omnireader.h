//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_OMNIREADER_H
#define OMNIREADER_OMNIREADER_H

#include <string>
#include <cstring>
#include <memory>

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
        /**
         * @return A pointer to the start of the current line in file.  nullptr if at end of file
         *
         * This buffer will always have at least 256 bytes following, so go nuts with your SIMD.
         */
        const char* line_start() const { return line_ptr; };
        /**
         * @return A pointer to the end of the current line
         *
         * If line_start is nullptr this is invalid
         */
        const char* line_end() const { return next_ptr == nullptr ? page_occupancy : next_ptr - 1; };
        /**
         * @return A copy of the current line
         */
        std::string get_line() const { return std::string(line_start(), line_end()); }
        /**
         * Advance the reader making a new line available
         *
         * @return if next line is available
         */
        bool advance();
        // Is a line available?
        inline bool at_eof() const { return line_ptr == nullptr; };
        // Reposition reader, currently only SEEK_SET allowed, returns success
        bool seek(unsigned long long, unsigned char);
        // Reposition reader to start of file, return if line available
        virtual bool rewind() = 0;
        // Current position of reader
        unsigned long long tell() const { return history + (line_ptr - page) ; };

    protected:
        char page[PAGESIZE];  // where data is stored
        char *line_ptr;  // points to current line, within page
        char *next_ptr;  // points to start of next line, within page
        char *page_occupancy;  // size of data stored, i.e. to where in *page* do we have data
        unsigned long long history; // total bytes not in page that we've progressed past
        void prepare_next();  // get the next line ready, sets EOF
        unsigned long long refill_page();
        virtual inline unsigned long long fill_page(unsigned long long remainder) = 0;
    };

    std::unique_ptr<Reader> GetReader(Format option);
}

#endif //OMNIREADER_OMNIREADER_H
