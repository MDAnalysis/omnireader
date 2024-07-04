import os
from skbuild import setup


setup(
    name='omnireader',
    packages=['omnireader'],
    cmake_args=['-DBUILD_PYTHON=ON'],
    python_requires=">=3.9",
    install_requires=[
        "numpy>=1.20.0",
    ]
)
