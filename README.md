# Otter Blink

![Otter Blink popup](docs/screenshot.png)

A KDE Plasma 6 panel widget that shows disk and network activity as little blinking LEDs, like the ones on the front of an old tower case. Red for disk reads, green for disk writes, and optional Ethernet and Wi-Fi pairs for receive and transmit. Click it for live transfer rates.

A companion to [Otter Power](https://github.com/MicahOttah/otter-power).

## Quick start

```
git clone https://github.com/MicahOttah/otter-blink.git
cd otter-blink
bash install.sh
bash verify.sh
```

Then restart the panel and add the "Otter Blink" widget:

```
plasmashell --replace >/dev/null 2>&1 & disown
```

## Disclaimer

Unlike its sibling, this one is harmless. It only reads three files under `/proc` and never writes anything. The worst it can do is blink at you.

Provided as is, with no warranty of any kind. See `LICENSE` for the formal terms.

## Tested on

- Dell Precision 7670, Fedora 44, KDE Plasma 6 on Wayland, kernel 7.2.x

Nothing here is specific to that machine. Any Plasma 6 system with the usual `/proc` files should work.

## What it does

**Panel**

- Disk read and write LEDs, summed across the disks you choose
- Optional Ethernet and Wi-Fi LED pairs (receive and transmit)
- LEDs scale to fit the panel thickness, in a row, stacked pairs, or stacked groups
- Optional R, W, E and Wi labels
- Tooltip with one-second average rates

**Popup (left-click)**

- Live rates for every enabled LED, each with its own blinking indicator
- The devices and interfaces each section is counting, so you can check your filters

**Configure (right-click)**

- General: colors, off brightness, LED size, spacing, layout, labels, poll interval, blink duration
- Disk: show or hide, device filter (regex), and what the write LED tracks
- Network: show or hide each pair, interface filters (regex), and a threshold to ignore background chatter

## Why the write LED sometimes looks lazy

Linux doesn't write to disk the moment a program saves data. Writes land in RAM (the page cache) and get flushed in batches every few seconds, and Btrfs commits every 30 seconds by default. During a big copy you will see quiet gaps and then a hard flash.

The Disk page has a setting for this:

- **Physical disk writes only**: what the drive actually does
- **Cache writes only**: lights when unwritten data in RAM is growing
- **Both** (default): either one lights the LED

The kernel only refreshes its cache counter about once per second, so cache mode pulses at roughly that rate.

## How it measures

| Source | Used for |
| --- | --- |
| `/proc/diskstats` | Sectors read and written (always 512-byte units) |
| `/proc/net/dev` | Bytes received and transmitted per interface |
| `/proc/meminfo` | The `Dirty` counter for cache mode |

The default disk filter matches whole physical disks (`sd`, `hd`, `vd`, `nvme`, `mmcblk`) and skips partitions, device mapper volumes and zram, so nothing is counted twice. The default interface filters match names starting with `en` or `eth` (Ethernet) and `wl` or `wlan` (Wi-Fi). Run `ip -br link` to see yours.

## Other ways to install

Each release on the Releases page has a source tarball, an RPM, a source RPM and a `SHA256SUMS` file.

From the tarball:

```
tar xzf otter-blink-VERSION.tar.gz
cd otter-blink-VERSION
bash install.sh
bash verify.sh
```

From the RPM, after removing any copy that was installed with `install.sh` (the two conflict):

```
sudo dnf install ./otter-blink-VERSION-1.fc44.noarch.rpm
```

The RPM is unsigned. Check the download against `SHA256SUMS` first if you want to be careful.

## What the installer does

It installs `kf6-kpackage` if `kpackagetool6` is missing, copies the applet to `~/plasmoids/io.github.micahottah.otterblink/`, and installs or upgrades it with `kpackagetool6`. No system files, no services, no sudo beyond that one package. It is safe to run more than once.

## Uninstall

Remove the widget from your panel first, then:

```
kpackagetool6 -t Plasma/Applet -r io.github.micahottah.otterblink
rm -rf ~/plasmoids/io.github.micahottah.otterblink
```

An RPM install is removed with `sudo dnf remove otter-blink`.

## Releasing (for maintainers)

`release.sh` bumps the patch version, commits, tags, builds the tarball and RPMs, writes checksums, and creates a draft GitHub release:

```
./release.sh 0.1.1 "One line describing the change"
```

## License

GPL-2.0-or-later. See `LICENSE`.
