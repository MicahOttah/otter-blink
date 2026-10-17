%global applet_id io.github.micahottah.otterblink

Name:           otter-blink
Version:        0.1.3
Release:        1%{?dist}
Summary:        Disk and network activity LEDs for KDE Plasma 6
License:        GPL-2.0-or-later
URL:            https://github.com/MicahOttah/otter-blink
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       plasma-workspace

%description
Otter Blink is a KDE Plasma 6 panel widget that shows disk read and write
activity, plus optional Ethernet and Wi-Fi receive and transmit activity, as
small blinking LEDs. Clicking it opens a popup with live transfer rates. It
only reads /proc/diskstats, /proc/net/dev and /proc/meminfo and changes
nothing on the system.

%prep
%autosetup

%build

%install
mkdir -p %{buildroot}%{_datadir}/plasma/plasmoids/%{applet_id}
cp -a files/home/plasmoid/. %{buildroot}%{_datadir}/plasma/plasmoids/%{applet_id}/

%files
%license LICENSE
%doc README.md
%{_datadir}/plasma/plasmoids/%{applet_id}/

%changelog
* Sat Oct 17 2026 MicahOttah <quinn@lionspaws.net> - 0.1.3-1
- Windows: DPI-aware, crisp tray icons at any scaling up to 250%

* Sat Oct 17 2026 MicahOttah <quinn@lionspaws.net> - 0.1.2-1
- Windows tray version for Windows 7 through 11

* Sat Oct 17 2026 MicahOttah <quinn@lionspaws.net> - 0.1.1-1
- Option to combine Ethernet and Wi-Fi LEDs into one pair

* Fri Oct 16 2026 MicahOttah <quinn@lionspaws.net> - 0.1.0-1
- Initial release

