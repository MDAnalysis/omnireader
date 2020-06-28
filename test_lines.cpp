//
// Created by richard on 27/06/2020.
//

#include <bzlib.h>

#include "omnireader.h"

void PrintLines(OmniReader* r) {
  for (unsigned char i=0; i<9; ++i) {
    fprintf(stdout, "---\n");
    const char* l = r->getline();
    if (l != NULL) {
      fprintf(stdout, "%lu\n", strlen(l));
      fprintf(stdout, ">%s<\n", l);
    }
    else
      fprintf(stdout, "Got null\n");
    fprintf(stdout, "---\n");
  }
}

int main(int argc, char* argv[]) {
  OmniReader* r;

  r = GetReader(BZ2);

  if (!r->open(argv[1])) {
    fprintf(stderr, "Failed to open file: %s\n", argv[1]);
    return 1;
  }

  PrintLines(r);

  return 0;
}