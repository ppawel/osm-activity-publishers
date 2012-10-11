#!/usr/bin/env python

import changemonger
import helpers
import sys

id = sys.argv[1]
cset = helpers.get_changeset_or_404(id)
sentence = changemonger.changeset_sentence(cset)
print sentence
