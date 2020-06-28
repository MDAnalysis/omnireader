//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_OMNIREADER_H
#define OMNIREADER_OMNIREADER_H

#include "omnibase.h"
#include "PlainTextReader.h"
#include "BZ2Reader.h"
#include "GZReader.h"

enum Format {
    PlainText,
    BZ2,
    GZ,
};

OmniReader* GetReader(Format option) {
  switch (option) {
    case PlainText:
      return new PlainTextReader();
    case BZ2:
      return new BZ2Reader();
    case GZ:
      return new GZReader();
    default:
      return NULL;
  }
}

#endif //OMNIREADER_OMNIREADER_H
