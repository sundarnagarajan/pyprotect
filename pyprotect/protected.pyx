include "doc.pxi"

import sys
cdef bint PY2
cdef object builtin_module
if sys.version_info.major > 2:
    PY2 = False
    builtin_module = sys.modules['builtins']
    import collections.abc as CollectionsABC
else:
    PY2 = True
    builtin_module = sys.modules['__builtin__']
    import collections as CollectionsABC
import os
import re
import types
import functools
import pydoc

include "python_visible.pxi"
include "global_cdefs.pxi"
include "global_c_functions.pxi"
include "ProtectionData.pxi"
include "Wrapped_Frozen.pxi"
include "PrivacyDict_FrozenPrivacyDict.pxi"
include "Private_FrozenPrivate.pxi"
include "Protected_FrozenProtected.pxi"
