win32-samples-rc-tests
======================

This branch contains a modified version of the test script that instead tests `resinator` integration in the Zig compiler.

Instead of compiling to `.res` and comparing the `.res` outputs, the `.res` files are linked into a `.dll` file and the `.rsrc` section of the `.dll`s are compared.

## Usage

### `setup.ps1`

`setup.ps1` must be run from one of the following in order to have access to all the necessary compilers:
 - 'Developer PowerShell for VS'
 - 'x86 Native Tools Command Prompt for VS'
 - An environment in which 'vcvars32.bat' has been executed

 (note: it must be the 32-bit environment because `uicc.exe` and `gc.exe` are not present in the 64-bit environment)

### `compare-rsrc.zig`

The `compare-rsrc` util must be compiled into an executable:
```
zig build-exe compare-rsrc.zig
```
This is used to allow comparing only the `.rsrc` section of the `.dll`s

### `test.ps1`

Requires `rc.exe` and `dumpbin.exe` to be somewhere in the `PATH` (see list above in `setup.ps1` for easy ways to do this), as well as a `zig` binary with `resinator` integrated.

Options:
- `-IncludePreprocessorQuirkFiles`: Includes `.rc` files that are known to rely on a Win32 RC preprocessor quirk (like how splices are collapsed within string literals)
- `-IncludeWin32WillCompileErrorFiles`: Includes `.rc` files that are known to cause compile errors when run through the Win32 `rc.exe` compiler. Most of these are files that have missing `#include`s that can't be salvaged via `setup.ps1`.
- `-ExcludeZigRC`: Don't test with `zig rc` even if it's found in the PATH
- `-ExitOnRCFailure`: Will cause the script to exit if `rc.exe` returns a non-zero exit code. Useful only when debugging `setup.ps1` to add support for more `.rc` files
- `-ErrorOnAnyDiscrepancies`: Will cause the script to exit with exit code `1` if any discrepancies are found. Useful when running in a CI environment
- `-ErrorOnAnyLikelyPanics`: Will cause the script to exit with exit code `1` if any likely crashes/panics are found. Useful when running in a CI environment
