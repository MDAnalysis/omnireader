//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_OMNIREADER_H
#define OMNIREADER_OMNIREADER_H

#include "PlainTextReader.h"
#include "BZ2Reader.h"

enum Format {
    PlainText,
    BZ2,
};

OmniReader* GetReader(Format option) {
  switch (option) {
    case PlainText:
      return new PlainTextReader;
    case BZ2:
      return new BZ2Reader;
    default:
      return NULL;
  }
}

#endif //OMNIREADER_OMNIREADER_H
