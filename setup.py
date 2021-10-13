import os
from setuptools import setup, Extension, find_packages
from Cython.Build import cythonize


try:
    # TODO: something smart about lib detection
    BASEPATH = os.environ['CONDA_PREFIX']
except:
    raise ValueError("Install libomnireader into conda first")
else:
    LIBPATH = os.path.join(BASEPATH, 'lib')
    INCPATH = os.path.join(BASEPATH, 'include')

groreader = Extension(
    name='omnireader.groreader',
    sources=['omnireader/groreader.pyx'],
    include_dirs=[INCPATH],
    library_dirs=[LIBPATH],
    libraries=['omnireader'],
    language='c++',
)


setup(
    name='omnireader',
    ext_modules=cythonize([groreader]),
    packages=find_packages(),
)
