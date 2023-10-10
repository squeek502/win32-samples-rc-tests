win32-samples-rc-tests
======================

A test suite for alternate `.rc` compilers ([`resinator`](https://github.com/squeek502/resinator), [`windres`](https://sourceware.org/binutils/docs/binutils/windres.html), `llvm-rc`) using the [Windows-classic-samples](https://github.com/microsoft/Windows-classic-samples) repository as the test corpus.

An overview of what this does:
- `setup.ps1` will modify things as necessary in the `Windows-classic-samples` submodule to get as many `.rc` files to compile as possible. This includes things like:
  + Adding files missing from the samples or the Windows SDK
  + Running other miscellaneous resource-adjacent compilers (`mc.exe`, `midl.exe`, `uicc.exe`, etc) to generate intermediate inputs used by `.rc` files
  + Converting some `UTF-16 with BOM`-encoded files to UTF-8/ASCII (since most preprocessors can't handle UTF-16)
- `test.ps1` will then run each `.rc` file through `rc.exe` to get the expected output, and then for each alternate RC compiler found, it will compile the `.rc` file and then compare the results to the `rc.exe` output. Any differences (`.res` output not byte-for-byte identical, missing compile error, unexpected compile error) are considered discrepancies and a report of all the discrepancies found is printed at the end of execution.

Results when testing with `resinator`, `llvm-rc 16.0.3`, and `windres 2.38`:

```
> .\test.ps1 -IncludeWin32WillCompileErrorFiles
Found RC compiler: resinator
Found RC compiler: windres
Found RC compiler: llvm-rc

Processed 485 .rc files

---------------------------
  resinator
---------------------------

485 .rc files processed without discrepancies
identical .res outputs:     460
expected compile errors:    25

---------------------------
  windres
---------------------------

395 .rc files processed with discrepancies
different .res outputs:     299
unexpected compile errors:  96
missing compile errors:     0

90 .rc files processed without discrepancies
identical .res outputs:     65
expected compile errors:    25

---------------------------
  llvm-rc
---------------------------

243 .rc files processed with discrepancies
different .res outputs:     89
unexpected compile errors:  154
missing compile errors:     0

242 .rc files processed without discrepancies
identical .res outputs:     217
expected compile errors:    25

---------------------------

See results.log for details about each file
```

## Usage

### `setup.ps1`

`setup.ps1` must be run from one of the following in order to have access to all the necessary compilers:
 - 'Developer PowerShell for VS'
 - 'x86 Native Tools Command Prompt for VS'
 - An environment in which 'vcvars32.bat' has been executed

 (note: it must be the 32-bit environment because `uicc.exe` and `gc.exe` are not present in the 64-bit environment)

### `test.ps1`

Requires `rc.exe` to be somewhere in the `PATH` (see list above in `setup.ps1` for easy ways to do this), as well as any of the alternate RC compilers you want to test.

Options:
- `-IncludePreprocessorQuirkFiles`: Includes `.rc` files that are known to rely on a Win32 RC preprocessor quirk (like how splices are collapsed within string literals)
- `-IncludeWin32WillCompileErrorFiles`: Includes `.rc` files that are known to cause compile errors when run through the Win32 `rc.exe` compiler. Most of these are files that have missing `#include`s that can't be salvaged via `setup.ps1`.
- `-ExcludeWindres`: Don't test with `windres` even if it's found in the PATH
- `-ExcludeLLVMRC`: Don't test with `llvm-rc` even if it's found in the PATH
- `-ExcludeResinator`: Don't test with `resinator` even if it's found in the PATH
- `-ExcludeZigRC`: Don't test with `zig rc` even if it's found in the PATH
- `-ExitOnRCFailure`: Will cause the script to exit if `rc.exe` returns a non-zero exit code. Useful only when debugging `setup.ps1` to add support for more `.rc` files
- `-ErrorOnAnyDiscrepancies`: Will cause the script to exit with exit code `1` if any discrepancies are found. Useful when running in a CI environment
- `-ErrorOnAnyLikelyPanics`: Will cause the script to exit with exit code `1` if any likely crashes/panics are found. Useful when running in a CI environment

### `clean.ps1`

`clean.ps1` can be run to 'reset' the state of the Windows-classic-samples submodule (remove all changes, untracked files, etc). Requires `git` to be on the `PATH`
