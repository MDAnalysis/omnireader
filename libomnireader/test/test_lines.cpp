//
// Created by richard on 27/06/2020.
//

#include <vector>
#include <string>

#include "omnireader.h"

using namespace OmniReader;

std::vector<int> PrintLines( const std::unique_ptr<Reader> &r) {
  std::vector<int> lengths;

  while (!r->at_eof()) {
    lengths.push_back(r->line_end() - r->line_start());
    std::string line(r->line_start(), r->line_end());

    fprintf(stderr, "%lu\t", line.size());
    fprintf(stderr, ">%s<\n", line.c_str());

    r->advance();
  }

  return lengths;
}

bool compare_lengths(std::vector<int>& ref, std::vector<int>& other) {
  if (ref.size() != other.size()) {
    fprintf(stderr, "Size mismatch: %zu %zu\n", ref.size(), other.size());
    return false;
  }

  for (unsigned int i=0; i<ref.size(); ++i) {
    if (ref[i] != other[i]) {
      fprintf(stderr, "Line length mismatch at %d: %d vs %d\n", i, ref[i], other[i]);
      return false;
    }
  }
  return true;
}

int main(int argc, char* argv[]) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s plaintextfile\n",argv[0]);
    return 1;
  }

  const char* fname = argv[1];

  auto r1 = GetReader(Format::PlainText);
  if (!r1->open(fname)) {
    fprintf(stderr, "Failed to open file: %s\n", argv[1]);
    return 1;
  }
  std::vector<int> ref_lengths = PrintLines(r1);

  std::string bz2fname(fname);
  bz2fname.append(".bz2");
  auto r2 = GetReader(Format::BZ2);
  if (!r2->open(bz2fname.c_str())) {
    fprintf(stderr, "Failed to open bz2 file\n");
    return 1;
  }
  std::vector<int> bz2_lengths = PrintLines(r2);

  std::string gzfname(fname);
  gzfname.append(".gz");
  auto r3 = GetReader(Format::GZ);
  if (!r3->open(gzfname.c_str())) {
    fprintf(stderr, "Failed to open gz file\n");
    return 1;
  }
  std::vector<int> gz_lengths = PrintLines(r3);

  if (!compare_lengths(ref_lengths, gz_lengths)) {
    fputs("Failed for GZip\n", stderr);
    return 2;
  }
  if (!compare_lengths(ref_lengths, bz2_lengths)) {
    fputs("Failed for BZ2\n", stderr);
    return 2;
  }

  return 0;
}
