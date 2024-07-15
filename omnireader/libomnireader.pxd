from libcpp cimport bool
from libcpp.string cimport string as stdstring
from libcpp.memory cimport unique_ptr


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

    unique_ptr[Reader] GetReader(int f)


cdef extern from "fast_float.h" namespace "fast_float":
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
