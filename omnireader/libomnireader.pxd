from libcpp cimport bool
from libcpp.string cimport string as stdstring
from libcpp.vector cimport vector
from libc.stdio cimport SEEK_SET


cdef extern from "Python.h":
    object PyUnicode_FromStringAndSize(const char* u, size_t size)


cdef extern from "omnireader.h" namespace "OmniReader":
    ctypedef enum Format:
        PlainText
        BZ2
        GZ

    cppclass Reader:
        Reader()
        bool open(const char* fname)
        const char* line_start()
        const char* line_end()
        stdstring get_line()
        bool advance()
        bool at_eof()
        bool seek(unsigned long long where, unsigned char whence)
        unsigned long long tell()
        bool rewind()

    Reader* GetReader(int f)


cdef extern from "fast_float/fast_float.h" namespace "fast_float":
    cppclass from_chars_result[UC]:
        pass

    from_chars_result from_chars[T, UC](const UC *start, const UC* end, T& result)


cdef inline unsigned int strtoint(const char* beg, const char* end):
    # fixed format file, so ints could be touching other ints, so strtoi can't be used
    # e.g. indices column could be touching the positions column
    cdef unsigned int ret = 0
    cdef char letter;

    # initial whitespace, this technically stops something like ' 1 23' being parsed as 123
    while (beg < end):
        letter = beg[0]
        if letter >= 48 and letter <= 57:
            break
        beg += 1

    # parse values
    while (beg < end):
        letter = beg[0]
        if not (letter >= 48 and letter <= 57):  # '0' <= l <= '9'
            break
        ret *= 10
        ret += letter - 48  # single char to number
        beg += 1

    return ret


# todo: this is behaving different through cython than above function
cdef inline int find_spans(const char *start, const char *end,
                    vector[int] &where):
    cdef const char* ptr
    cdef bool saw_token = False
    cdef bool is_whitespace

    ptr = start

    while ptr < end:
        # todo: better definition of whitespace, e.g. \t
        is_whitespace = ptr[0] == b' '
        if saw_token == is_whitespace:
            saw_token = not saw_token
            where.push_back(ptr - start)
        ptr += 1
    if saw_token:  # if nonwhitespace reached end of buffer, tag final char as end of last span
        where.push_back(ptr - start)

    return where.size()
