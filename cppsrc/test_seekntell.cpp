//
// Created by richard on 31/03/2021.
//

#include <string>
#include <vector>
#include <iostream>

#include "omnireader.h"

int main(int argc, const char* argv[]) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s plaintextfile\n",argv[0]);
    return 1;
  }

  const char* fname = argv[1];

  OmniReader::Reader* r = OmniReader::GetReader(OmniReader::Format::PlainText);
  r->open(fname);

  std::cout << r->tell() << "\t";
  std::cout << r->getline();
  std::cout << r->tell() << "\t";
  std::cout << r->getline();
  std::cout << r->tell() << "\n";

  r->seek(5, SEEK_SET);
  std::cout << r->tell() << "\t";
  std::cout << r->getline();

  r->seek(12, SEEK_SET);
  std::cout << r->tell() << "\t" << r->getline();
}
