from setuptools import setup, Extension, find_packages
from Cython.Build import cythonize

groreader = Extension(
    name='omnireader.groreader',
    sources=['pysrc/groreader.pyx'],
    include_dirs=['/home/richard/miniconda3/envs/mda/include/'],
    library_dirs=['/home/richard/miniconda3/envs/mda/lib/'],
    libraries=['omnireader'],
    language='c++',
)


setup(
    name='omnireader',
    ext_modules=cythonize([groreader]),
    packages=find_packages('pysrc'),
)
