//
// Created by richard on 27/06/2020.
//

#include "omnireader.h"

void PrintLines(OmniReader* r) {
  while (!r->at_eof()) {
    std::string l = r->getline();
    fprintf(stderr, "%lu\t", l.size());
    fprintf(stderr, ">%s<\n", l.c_str());
  }
}

int main(int argc, char* argv[]) {

  PlainTextReader* r1 = (PlainTextReader*) GetReader(Format::PlainText);

  if (!r1->open(argv[1])) {
    fprintf(stderr, "Failed to open file: %s\n", argv[1]);
    return 1;
  }

  PrintLines(r1);

  delete r1;

  BZ2Reader* r2 = (BZ2Reader*) GetReader(Format::BZ2);
  if (!r2->open("/home/richard/test/omni/test.txt.bz2")) {
    fprintf(stderr, "Failed to open bz2 file\n");
    return 1;
  }
  PrintLines(r2);

  GZReader gz;
  if (!gz.open("/home/richard/test/omni/test.txt.gz")) {
    fprintf(stderr, "Failed to open gz file\n");
    return 1;
  }
  PrintLines(&gz);

  return 0;
}
