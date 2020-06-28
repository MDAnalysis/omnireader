//
// Created by richard on 27/06/2020.
//

#include "omnireader.h"

int main(int argc, char* argv[]) {
  PlainTextReader p;

  FILE* f = fopen(argv[1], "r");
  if (f == NULL) {
    return 4;
  }

  if (!p.open(argv[1])) {
    fprintf(stderr, "Failed to open file: %s\n", argv[1]);
    return 1;
  }

  for (unsigned char i=0; i<9; ++i) {
    fprintf(stdout, "---\n");
    const char* l = p.getline();
    if (l != NULL) {
      fprintf(stdout, "%lu\n", strlen(l));
      fprintf(stdout, ">%s<\n", l);
    }
    else
      fprintf(stdout, "Got null\n");
    fprintf(stdout, "---\n");
  }
}