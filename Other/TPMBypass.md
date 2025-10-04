# Upgrade to Windows 11 without the TPM check

> **Warning / Backup:** Proceed only if you understand the risks. Unsupported systems may not receive updates, may miss security features, and Microsoft may limit support. **Back up your system (full image)** before attempting any upgrade.

## Option A — Registry patch (recommended for in-place upgrades)

This is the simplest method to allow an **in-place upgrade** (keeps apps, files, settings).

**.reg file (downloadable):** [Download `BypassTPM.reg`](bypasstpm.reg)

**Manual steps (if you prefer not to use the .reg file):**

1. Open **Notepad**.
2. Paste the following text:

   ```reg
   Windows Registry Editor Version 5.00

   [HKEY_LOCAL_MACHINE\SYSTEM\Setup\MoSetup]
   "AllowUpgradesWithUnsupportedTPMOrCPU"=dword:00000001
   ```
3. Save as `BypassTPM.reg` — choose **All files** in the Save dialog.
4. Double-click `BypassTPM.reg` and accept the User Account Control and registry prompts to add it.
5. (Optional) Restart the PC.
6. Run `setup.exe` from the Windows 11 ISO or USB to start the upgrade. You’ll see a warning that your device is unsupported — you can continue.

**Notes:** This is the same key Microsoft documents for advanced scenarios. It disables the CPU/TPM/secure-boot block for setup.

---

## Option B — Remove or replace the `appraiserres.dll` in the installation media

This method disables the compatibility check inside the Windows Setup media itself. Use when you want to boot from media or run setup from ISO/USB.

**Steps:**

1. Obtain a Windows 11 ISO (official Microsoft ISO recommended).
2. Mount the ISO (right-click → Mount) or extract it with a tool.
3. Open the mounted drive (or extracted folder) and go to the `sources` folder.
4. Find `appraiserres.dll`. Make a copy of the original (store it somewhere safe), then **delete** `appraiserres.dll` from the `sources` folder on the installation media.

   * Alternatively, replace it with an inert (empty) file with the same name.
5. Run `setup.exe` from the modified media (or boot from it). The hardware compatibility check will be bypassed and the upgrade/installation will proceed.
6. After installation, restore the original file in your saved copy if needed.

**Notes / Risks:**

* Modifying installation media is unsupported by Microsoft and may trigger warnings.
* Always keep an untouched original ISO as a backup.

---

## Option C — Use Rufus to create a bypassed installer (clean install or upgrade via USB)

Rufus can create an ISO/USB that bypasses TPM/Secure Boot checks and optionally creates an installer that behaves like the official media but with checks disabled. This is good for clean installs or if you prefer a prepared USB.

**High-level steps:**

1. Download the latest Rufus from its official site.
2. Prepare a USB drive (data will be erased).
3. In Rufus:

   * Select the Windows 11 ISO.
   * For "Image option", choose the option that mentions bypassing TPM/secure boot checks (Rufus labels these options explicitly).
   * Choose partition scheme and target system according to your machine (MBR/BIOS or GPT/UEFI).
   * Start and allow Rufus to create the USB.
4. Boot from the Rufus-created USB or run `setup.exe` from the USB to install or upgrade.
5. Follow on-screen prompts. Rufus-made media typically lets you proceed even if your device is "unsupported."

**Notes:**

* Rufus provides user-friendly toggles for bypassing checks; read the Rufus dialog carefully.
* Rufus-based installs are more likely to be clean installs, though you can run setup.exe for an in-place upgrade if supported.

---

## After the upgrade

* Check Windows Update settings. Microsoft may mark your device as unsupported and you might not receive feature updates automatically.
* If you rely on TPM for BitLocker, note that BitLocker features tied to TPM may not work on unsupported hardware.
* If you used Option B or C and you need the original `appraiserres.dll` later, restore it from your backup.

---

## Quick comparison

* **Registry patch (A)** — Best for in-place upgrade; easiest; minimal file changes. Keeps apps/settings.
* **Remove `appraiserres.dll` (B)** — Works from media; good if you prefer editing the ISO; somewhat manual.
* **Rufus (C)** — Easiest for creating bypassable bootable USBs; useful for clean installs and versatile options.
