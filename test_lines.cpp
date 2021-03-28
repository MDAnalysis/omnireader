//
// Created by richard on 27/06/2020.
//

#include <string>

#include "omnireader.h"

void PrintLines(OmniReader* r) {
  while (!r->at_eof()) {
    std::string l = r->getline();
    fprintf(stderr, "%lu\t", l.size());
    fprintf(stderr, ">%s<\n", l.c_str());
  }
}

int main(int argc, char* argv[]) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s plaintextfile\n",argv[0]);
    return 1;
  }

  const char* fname = argv[1];

  OmniReader* r1 = GetReader(Format::PlainText);
  if (!r1->open(fname)) {
    fprintf(stderr, "Failed to open file: %s\n", argv[1]);
    return 1;
  }
  PrintLines(r1);
  delete r1;

  std::string bz2fname(fname);
  bz2fname.append(".bz2");
  OmniReader* r2 = GetReader(Format::BZ2);
  if (!r2->open(bz2fname.c_str())) {
    fprintf(stderr, "Failed to open bz2 file\n");
    return 1;
  }
  PrintLines(r2);
  delete r2;

  std::string gzfname(fname);
  gzfname.append(".gz");
  OmniReader* r3 = GetReader(Format::GZ);
  if (!r3->open(gzfname.c_str())) {
    fprintf(stderr, "Failed to open gz file\n");
    return 1;
  }
  PrintLines(r3);
  delete r3;

  return 0;
}
