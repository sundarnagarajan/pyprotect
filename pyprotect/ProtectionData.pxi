
@cython.final
@cython.internal
cdef class _ProtectionData(object):
    '''
    Attributes:
        id: int
        hash: method (no args) -> int
        isinstance: method: isinstance(o, x)
            identical to standard isinstance
        issubclass: method: issubclass(o, x)
            identical to standard issubclass
        help: method (no args)
        help_str: method (no args) -> str
        testop: method: testop(a: str, op: str) -> bool
        rules: dict
        freeze: method (no args) -> Wrapped
        private: method (no args) -> Private
        multiwrapped: method (no args) -> bool
    '''
    cdef public object id
    cdef public object hash
    cdef public object isinstance
    cdef public object issubclass
    cdef public object help
    cdef public object help_str
    cdef public object testop
    cdef public object rules
    cdef public object freeze
    cdef public object private
    cdef public object protect
    cdef public object multiwrapped
    cdef object attributes_map

    def __init__(
        self,
        id_val,
        hash_val,
        isinstance_val,
        issubclass_val,
        help_val,
        help_str,
        testop,
        rules,
        freeze,
        private,
        protect,
        multiwrapped,
    ):
        self.id = id_val
        self.hash = hash_val
        self.isinstance = isinstance_val
        self.issubclass = issubclass_val
        self.help = help_val
        self.help_str = help_str
        self.testop = testop
        self.rules = rules
        self.freeze = freeze
        self.multiwrapped = multiwrapped
        self.private = private
        self.protect = protect

        self.attributes_map = {
            'id': self.id,
            'hash': self.hash,
            'isinstance': self.isinstance,
            'issubclass': self.issubclass,
            'help': self.help,
            'help_str': self.help_str,
            'testop': self.testop,
            'rules': self.rules,
            'freeze': self.freeze,
            'private': self.private,
            'protect': self.protect,
            'multiwrapped': self.multiwrapped,
            '__class__': _ProtectionData,
        }

    def __getattribute__(self, a):
        if a in self.attributes_map:
            return self.attributes_map.get(a)
        missing_msg = "Object '%s' has no attribute '%s'" % (
            '_ProtectionData',
            str(a)
        )
        raise AttributeError(missing_msg)

    def __setattr__(self, a, val):
        raise ProtectionError('Object is read-only')

    def __delattr__(self, a):
        raise ProtectionError('Object is read-only')

    def __dir__(self):
        return list(self.attributes_map.keys())

