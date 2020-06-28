//
// Created by richard on 27/06/2020.
//

#ifndef OMNIREADER_OMNIREADER_H
#define OMNIREADER_OMNIREADER_H

#include "PlainTextReader.h"

OmniReader* GetReader() {
  return new PlainTextReader;
}

#endif //OMNIREADER_OMNIREADER_H
