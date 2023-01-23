This directory contains files that are either missing from the Windows-classic-samples repository or are missing from the Windows SDK

- `gallery.xml` is meant to be included in the `WindowsRibbon/Gallery` sample, but it is missing. The `gallery.xml` provided here comes from the [`Windows Ribbon: Samples` download here](https://www.microsoft.com/en-us/download/details.aspx?id=9620) and the relevant issue in the Windows-classic-samples repo is [here](https://github.com/microsoft/Windows-classic-samples/issues/131).
- `verinfo.ver` is a file that was provided in the Windows SDK at some point, but seems to no longer be provided. The `verinfo.ver` provided here comes from [MinGW](https://www.mingw-w64.org/) ([SourceForge](https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/tree/mingw-w64-headers/include/verinfo.ver), [GitHub](https://github.com/mingw-w64/mingw-w64/blob/master/mingw-w64-headers/include/verinfo.ver)).

Additionally, the `setup` script may convert some `UTF-16 with BOM`-encoded Windows SDK `.rc` files and copy the converted versions here.
