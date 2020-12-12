

class TestObj(object):
    def __init__(self, x=1, y=2):
        self.__x = x
        self.__y = y
        self.__private = 1
        self._ro = 2
        self.rw = 5

    def sum(self):
        return self.x + self.y

    @property
    def x(self):
        return self.__x

    @property
    def y(self):
        return self.__y

    def inc_ro(self):
        self._ro += 1

    def pvt(self):
        return self.__private

    def __eq__(self, other):
        if self is other:
            return True
        return False


if __name__ == '__main__':
    import doctest

    doctest.testfile('testcases.txt')
