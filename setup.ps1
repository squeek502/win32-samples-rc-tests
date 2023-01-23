. ".\_common.ps1"

# Ensure that all of the necessary commands are available on the PATH
Ensure-HasCommand "mc.exe"
Ensure-HasCommand "midl.exe"
Ensure-HasCommand "fxc.exe"
Ensure-HasCommand "gc.exe"
Ensure-HasCommand "ctrpp.exe"
Ensure-HasCommand "uicc.exe"

# There are two problems with this file:
# 1. It is UTF-16 encoded, which usually can't be handled by the preprocessors of alternative resource compiler implementations
# 2. Git's line ending hanlding mangles the file
$filename = "Windows-classic-samples\Samples\DirectWriteCustomFontSets\cpp\Resource.rc"
Set-Content -Path "$filename" -Value "ICONFONT FONTFILE `"Fonts\\Symbols.ttf`"`r`nBODYTEXTFONT FONTFILE `"Fonts\\selawk.ttf`""

# This file includes a relative header using <> instead of "" which is an error in some preprocessors
$filename = "Windows-classic-samples\Samples\Win7Samples\multimedia\directshow\filters\sampvid\sampvid.rc"
((Get-Content -Path "$filename" -Raw) `
    -replace '#include <vidprop.h>','#include "vidprop.h"') |
    Set-Content -Path "$filename"

# Same with this file
$filename = "Windows-classic-samples\Samples\Win7Samples\multimedia\Direct2D\DXGISample\DxgiSample.rc"
((Get-Content -Path "$filename" -Raw) `
    -replace '#include <dxgisample.resinclude>','#include "dxgisample.resinclude"') |
    Set-Content -Path "$filename"

# And this one, too
$filename = "Windows-classic-samples\Samples\Win7Samples\multimedia\Direct2D\Interactive3dTextSample\Interactive3dTextSample.rc"
((Get-Content -Path "$filename" -Raw) `
    -replace '#include <extrusionsample.resinclude>','#include "extrusionsample.resinclude"') |
    Set-Content -Path "$filename"

# This file has interface/typedef redefinitions that cause errors, so we need to comment them out
$filename = "Windows-classic-samples\Samples\Win7Samples\winui\speech\engines\samplesrengine\SampleSrEngine.idl"
(Get-Content $filename) |
    Foreach-Object -Begin {$line = 1; $done = 0} -Process {
        # If the changes have already been made, then don't make them again
        if ($line -eq 18 -and $_ -eq "/*") { $done = 1 }
        if (-not $done) {
            if ($line -eq 18 -or $line -eq 42) { "/*" }
            if ($line -eq 30 -or $line -eq 58) { "*/" }
        }
        $_ # send the current line to output
        $line++
    } | Set-Content $filename

# Some files include "afxres.rc" and/or "afxprint.rc" which are distributed in the Windows SDK
# and may be encoded as UTF-16 with BOM which not all preprocessors can handle, so we need to
# find them, convert them to ASCII, and then put it in the `files` directory so that things
# that need it can get the ASCII version if necessary
#
# Returns the full path to the converted file, or $null if the file did not need to be converted
function Get-AndMaybeConvertIncludedRc {
    param ( $rc_filename )

    $include_paths = $env:INCLUDE -split ';'
    $rc_path = $null
    foreach ($include_path in $include_paths) {
        if (Test-Path -Path "$include_path\$rc_filename") {
            $rc_path = "$include_path\$rc_filename"
            break
        }
    }
    if ($null -eq $rc_path) {
        Write-Error "Unable to find $rc_filename in INCLUDE environment variable"
        exit 1
    } elseif (Test-IsUtf16Le "$rc_path") {
        $rc_dest_path = "files\$rc_filename"
        Get-Content "$rc_path" -Encoding unicode | Set-Content -Encoding Ascii "$rc_dest_path"
        return Resolve-Path -LiteralPath "$rc_dest_path"
    }
    return $null
}
$converted_afxres = Get-AndMaybeConvertIncludedRc "afxres.rc"
$converted_afxprint = Get-AndMaybeConvertIncludedRc "afxprint.rc"

Push-Location "Windows-classic-samples\Samples\NetworkAccessProtectionExtensions\cpp\SHA\DLL"
mc.exe Messages.mc
Pop-Location

Push-Location "Windows-classic-samples\Samples\UPnPDimmerService\cpp"
midl.exe /sal DimmerDevice.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\VolumeShadowCopyServiceProvider\cpp"
mc.exe eventlogmsgs.mc
midl.exe VssSampleProvider.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\WebServices\FileRepService\cpp"
mc.exe FileRep.mc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\com\administration\spy\comspy"
midl.exe ..\comspyface\ComSpy.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\com\administration\spy\comspyaudit"
midl.exe ..\comspyface\ComSpyAudit.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\com\administration\spy\comspyctl"
midl.exe ..\comspyface\ComSpyCtl.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\dataaccess\oledb\omniprov\source"
midl.exe theprovider.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\dataaccess\oledb_conformance\ado\tools\adopriv"
midl.exe adopriv.idl
Pop-Location

# `verinfo.ver` seems to have been included in the Windows Platform SDK at some point, but is no longer included
# in recent versions.
Copy-Item -Path "files\verinfo.ver" -Destination "Windows-classic-samples\Samples\Win7Samples\multimedia\audio\midiplyr"

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\Direct2D\DXGISample"
fxc.exe /T fx_4_0 /Fo dxgisample.fxo dxgisample.fx
Set-Content -Path dxgisample.resinclude -Value "IDR_PIXEL_SHADER RCDATA dxgisample.fxo"
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\Direct2D\Interactive3dTextSample"
fxc.exe /T fx_4_0 /Fo extrusionsample.fxo extrusionsample.fx
Set-Content -Path extrusionsample.resinclude -Value "IDR_PIXEL_SHADER RCDATA extrusionsample.fxo"
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\gdi\icm\devicemodelplugin"
midl.exe /D USE_SDK_INC DeviceModelPluginSample.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\gdi\icm\gamutmapmodelplugin"
midl.exe /D USE_SDK_INC GamutMapModelPluginSample.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\mediafoundation\topoedit\tedutil"
midl.exe tedutil.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\windowsmediaservices9\authentication"
midl.exe Authenticate.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\windowsmediaservices9\authorization"
midl.exe dbauth.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\windowsmediaservices9\cacheproxy\cplusplus"
midl.exe proxyplugin.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\windowsmediaservices9\datasource"
midl.exe sdksamplestorageplugin.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\windowsmediaservices9\eventnotification\contextsampleproppage"
midl.exe ContextSamplePropPage.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\multimedia\windowsmediaservices9\eventnotification"
midl.exe ContextDll.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\netds\messagequeuing\mqpers\graphobj"
midl.exe GraphObj.Idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\netds\nap\sha\dll"
mc.exe Messages.mc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\netds\tapi\tapi3\cpp\msp\samplemsp"
midl.exe SampMsp.Idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\netds\tapi\tapi3\cpp\pluggable"
midl.exe plgtermsample.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\netds\upnp\dco_dimmerservice"
midl.exe DimmerDevice.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\security\certificateservices\exit\c++\windowsserver2008"
midl.exe certxsam.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\security\certificateservices\exit\c++\WindowsServer2008R2"
midl.exe certxsam.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\security\certificateservices\policy\c++\windowsserver2008"
midl.exe certpsam.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\security\certificateservices\policy\c++\WindowsServer2008R2"
midl.exe certpsam.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\web\iis\components\cpp\simple"
midl.exe CatlSmpl.Idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\web\WWSAPI\FileRepService"
mc.exe FileRep.mc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\DeviceFoundation\PNPX\SimpleThermostat\UPnP\UPnPSimpleThermostatDeviceDLL"
midl.exe SimpleThermostatDevice.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\Eventing\Provider\Advanced\CPP"
mc.exe -um AdvancedProvider.man -z AdvancedProviderEvents
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\Eventing\Provider\Simple\CPP"
mc.exe -um SimpleProvider.man -z SimpleProviderEvents
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\FSRM\SampleIFilterBasedClassifier\CPP\ContentBasedClassificationModule"
midl.exe ContentBasedClassificationModule.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\FSRM\SampleIFilterBasedClassifier\CPP\FsrmTextReader"
midl.exe FsrmTextReader.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\FSRM\SampleTextBasedClassifier\CPP"
midl.exe FsrmSampleClassificationModule.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\imapi\imapiv2\erasesample\erasesample"
midl.exe EraseSample.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\PerfCounters\Basic\CPP"
ctrpp.exe -o ucsCounters.h -rc ucsCounters.rc ucs.man
# ctrpp outputs .rc files that are UTF-16 encoded, so we need to convert it
Get-Content ucsCounters.rc -Encoding unicode | Set-Content -Encoding Ascii ucsCountersAscii.rc
Move-Item -Path ucsCountersAscii.rc -Destination ucsCounters.rc -Force
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\PerfCounters\GlobalAggregate\CPP"
ctrpp.exe -o gasCounters.h -rc gasCounters.rc gas.man
# ctrpp outputs .rc files that are UTF-16 encoded, so we need to convert it
Get-Content gasCounters.rc -Encoding unicode | Set-Content -Encoding Ascii gasCountersAscii.rc
Move-Item -Path gasCountersAscii.rc -Destination gasCounters.rc -Force
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\rdc\server"
midl.exe RdcSdkTestServer.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\vss\vsssampleprovider"
midl.exe vsssampleprovider.idl
mc.exe eventlogmsgs.mc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\winnt\perftool\perfdlls\appmem\perfdll"
mc.exe MemCtrs.Mc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winbase\winnt\perftool\perfdlls\perfgen"
mc.exe GenCtrs.Mc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\dictationpad"
gc.exe cmdmode.xml -h cmdmode.h
gc.exe dictmode.xml -h dictmode.h
gc.exe chs_cmdmode.xml -h chs_cmdmode.h
gc.exe chs_dictmode.xml -h chs_dictmode.h
gc.exe cht_cmdmode.xml -h cht_cmdmode.h
gc.exe cht_dictmode.xml -h cht_dictmode.h
gc.exe deu_cmdmode.xml -h deu_cmdmode.h
gc.exe deu_dictmode.xml -h deu_dictmode.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\engines\samplesrengine"
midl.exe SampleSrEngine.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\engines\samplettsengine\samplettsengine"
midl.exe SampleTtsEngine.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\reco"
gc.exe chs_sol.xml -h chs_sol.h
gc.exe cht_sol.xml -h cht_sol.h
gc.exe deu_cardinals.xml -h deu_cardinals.h
gc.exe eng_sol.xml -h eng_sol.h
gc.exe esp_dates.xml -h esp_dates.h
gc.exe fra_cardinals.xml -h fra_cardinals.h
gc.exe itn_j.xml -h itn_j.h
gc.exe jpn_sol.xml -h jpn_sol.h
gc.exe kor_cardinals.xml -h kor_cardinals.h
gc.exe sol.ENG.xml -h sol.ENG.h
gc.exe sol.xml -h sol.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\simpleaudio"
midl.exe /D SAPI_AUTOMATION simpleaudio.idl
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\tutorial\coffeeshop0"
gc.exe coffee.xml -h cofgram.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\tutorial\coffeeshop1"
gc.exe coffee.xml -h cofgram.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\tutorial\coffeeshop2"
gc.exe coffee.xml -h cofgram.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\tutorial\coffeeshop3"
gc.exe coffee.xml -h cofgram.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\tutorial\coffeeshop4"
gc.exe coffee.xml -h cofgram.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\tutorial\coffeeshop5"
gc.exe coffee.xml -h cofgram.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\speech\tutorial\coffeeshop6"
gc.exe coffee.xml -h cofgram.h
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\ContextPopup\CPP"
uicc.exe ContextPopup.xml ContextPopup.bml /header:ids.h /res:ContextPopupUI.rc /name:ContextPopup
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\DropDownColorPicker\CPP"
uicc.exe ribbonmarkup.xml ribbonmarkup.bml /header:ribbonres.h /res:ribbonresUI.rc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\FontControl\CPP"
uicc.exe ribbonmarkup.xml ribbonmarkup.bml /header:ids.h /res:FontControlUI.rc /name:FontControl
Pop-Location

# `gallery.xml` is missing from this sample, but it was included in previous SDKs, so copy it in
Copy-Item -Path "files\gallery.xml" -Destination "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\Gallery\CPP"

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\Gallery\CPP"
uicc.exe gallery.xml gallery.bml /header:ids.h /res:galleryUI.rc
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\HTMLEditRibbon\CPP"
if ($converted_afxprint) { Copy-Item -Path "$converted_afxprint" -Destination "afxprint.rc" }
mkdir -Force RibbonRes > $null
uicc.exe Ribbon/ribbonmarkup.xml RibbonRes/ribbonmarkup.bml /header:RibbonRes/ribbonres.h /res:RibbonRes/ribbonres.rc2
Pop-Location

Push-Location "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\SimpleRibbon\CPP"
uicc.exe SimpleRibbon.xml SimpleRibbon.bml /header:SimpleRibbonUI.h /res:SimpleRibbonUI.rc /name:SimpleRibbon
Pop-Location

# All these will need afxres.rc (if it needed to be converted)
if ($converted_afxres) {
    foreach ($dir in @(
        "Windows-classic-samples\Samples\AmbientLightAware\cpp",
        "Windows-classic-samples\Samples\UPnPGenericUCP\cpp",
        "Windows-classic-samples\Samples\Win7Samples\com\administration\explore.vc",
        "Windows-classic-samples\Samples\Win7Samples\multimedia\directshow\dmo\dmodemo",
        "Windows-classic-samples\Samples\Win7Samples\multimedia\windowsmediaformat\wmgenprofile\exe",
        "Windows-classic-samples\Samples\Win7Samples\netds\adsi\general\adqi",
        "Windows-classic-samples\Samples\Win7Samples\netds\messagequeuing\c_draw",
        "Windows-classic-samples\Samples\Win7Samples\netds\messagequeuing\imp_draw",
        "Windows-classic-samples\Samples\Win7Samples\netds\messagequeuing\mqapitst",
        "Windows-classic-samples\Samples\Win7Samples\netds\messagequeuing\mqf_draw",
        "Windows-classic-samples\Samples\Win7Samples\netds\upnp\genericucp\cpp",
        "Windows-classic-samples\Samples\Win7Samples\netds\wlan\WirelessHostedNetwork\HostedNetwork",
        "Windows-classic-samples\Samples\Win7Samples\sysmgmt\wmi\vc\advclient",
        "Windows-classic-samples\Samples\Win7Samples\sysmgmt\wmi\vc\eventconsumer",
        "Windows-classic-samples\Samples\Win7Samples\tabletpc\realtimestylusplugin\cpp",
        "Windows-classic-samples\Samples\Win7Samples\winbase\cluster\win2003\clipbookserver\clipbook serverex",
        "Windows-classic-samples\Samples\Win7Samples\winbase\cluster\win2003\filesharesample\file share sampleex",
        "Windows-classic-samples\Samples\Win7Samples\winbase\FSRM\EnumClassificationProperties\cpp",
        "Windows-classic-samples\Samples\Win7Samples\winbase\wtsapi",
        "Windows-classic-samples\Samples\Win7Samples\winui\Sensors\AmbientLightAware",
        "Windows-classic-samples\Samples\Win7Samples\winui\WindowsRibbon\HTMLEditRibbon\CPP"
    )) {
        Copy-Item -Path "$converted_afxres" -Destination "$dir\afxres.rc"
    }
}
