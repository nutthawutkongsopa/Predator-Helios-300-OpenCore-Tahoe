# Predator Helios 300 PH315-51 (OC 1.0.8)
## Labtop Spec

> CPU&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;Intel Core i7-8750H CPU @ 2.20GHz (Coffee Lake)  
> RAM&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;16 GB DDR4  
> Graphics&emsp;&emsp;&emsp;&emsp;Intel UHD Graphics 630  
> OS&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&nbsp;&nbsp;macOS Tahoe 26 (last macOS release supporting Intel Macs)

## Versions

| Component | Version |
|---|---|
| OpenCore | 1.0.8 |
| Lilu | 1.7.2 |
| WhateverGreen | 1.7.1 |
| AppleALC | 1.9.8 |
| VirtualSMC (+ SMC plugins) | 1.3.8 |
| NVMeFix | 1.1.3 |
| BrightnessKeys | 1.0.3 |
| CPUFriend | 1.3.0 |
| HibernationFixup | 1.5.4 |
| CpuTscSync | 1.1.2 |
| VoodooPS2Controller | 2.3.7 |
| VoodooInput | 1.1.6 |
| VoodooI2C / VoodooI2CHID | 2.9.1 |
| IntelBluetoothFirmware | 2.4.0 |
| BlueToolFixup (BrcmPatchRAM) | 2.7.2 |
| RealtekRTL8111 | 3.0.0 |
| USBInjectAll | 0.8.1 |
| itlwm | 2.3.0 |

## Notes

- **Wi-Fi:** `AirportItlwm` has no build newer than Sonoma 14.4, so this EFI uses the generic `itlwm.kext`. Install the [HeliPort](https://github.com/OpenIntelWireless/HeliPort) app to connect to Wi-Fi.
- Upgraded from the Sonoma EFI; `config.plist` was updated for OpenCore 1.0.8 (`ClearTaskSwitchBit`, per-driver `HideVerbose`) and validated with `ocvalidate`.
- `HfsPlus.efi` comes from [OcBinaryData](https://github.com/acidanthera/OcBinaryData).
- **USB installer (Linux):** `./scripts/make-usb-installer.sh download` fetches the latest macOS recovery + HeliPort v1.5.0 + the v2.0.0-alpha fallback (`.dmg`s copied to `HeliPort/` on the USB); `sudo ./scripts/make-usb-installer.sh /dev/sdX` erases that USB and writes this EFI + recovery. Boot it, pick *macOS Base System*, erase the target in Disk Utility, then Reinstall macOS (needs Ethernet / USB tethering — HeliPort cannot run in recovery).
- **Replace OpenCore on this machine (Linux):** `sudo ./scripts/install-efi.sh [--dry-run]` backs up existing `EFI/OC*` to `~/efi-backup/`, installs `EFI/OC` to the ESP, and swaps the UEFI boot entries (other OSes untouched).
- `HideAuxiliary` is off so the recovery entry ("macOS Base System") shows in the picker. `OC/Resources` comes from [OcBinaryData](https://github.com/acidanthera/OcBinaryData) (not part of the OpenCorePkg zip).
- **SMBIOS is MacBookPro16,1**: macOS Tahoe does not support MacBookPro15,x (the old model shows the 🚫 prohibitory sign). Generate your own serial/MLB/UUID with `macserial -m MacBookPro16,1` if you reuse this EFI.
- **USBMap** is in the macOS 26 format (`AppleUSBHostMergeProperties` + `usb-port-number`/`usb-port-type`, model MacBookPro16,1). Re-map with [USBMap](https://github.com/corpnewt/USBMap) if you reuse this EFI on other hardware.
- Not boot-tested on hardware — keep a working Sonoma EFI on a USB stick as a fallback.
