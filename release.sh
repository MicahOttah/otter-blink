#!/bin/bash
# Usage: ./release.sh 0.1.1 "One line describing the change"
set -euo pipefail

VERSION=${1:?usage: release.sh X.Y.Z "changelog message"}
MSG=${2:?usage: release.sh X.Y.Z "changelog message"}
REPO="MicahOttah/otter-blink"
APPLET_ID="io.github.micahottah.otterblink"

cd "$(dirname "$(readlink -f "$0")")"

case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "Version must look like 0.1.1"; exit 1 ;;
esac

for tool in rpmbuild dotnet zip gh; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing $tool. Install it first."; exit 1; }
done

EMAIL=$(git config user.email || true)
[ -n "$EMAIL" ] || { echo "Set git user.email first."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Uncommitted changes. Commit them first."; exit 1; }
git fetch origin
git merge-base --is-ancestor origin/main HEAD || { echo "GitHub has commits you don't have. Pull first."; exit 1; }
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
  echo "Tag v$VERSION already exists locally."
  exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists on GitHub."
  exit 1
fi

START=$(git rev-parse HEAD)
FINISHED=0
undo() {
  if [ "$FINISHED" -eq 0 ]; then
    echo
    echo "Stopped before pushing. Nothing was sent to GitHub."
    echo "To discard the local release commit and tag:"
    echo "  git tag -d v$VERSION; git reset --hard $START"
  fi
}
trap undo EXIT

echo "== bump version to $VERSION"
sed -i "s/\"Version\": \"[^\"]*\"/\"Version\": \"$VERSION\"/" files/home/plasmoid/metadata.json
grep -q "\"Version\": \"$VERSION\"" files/home/plasmoid/metadata.json
sed -i "s|<Version>[^<]*</Version>|<Version>$VERSION</Version>|" windows/OtterBlink.csproj
grep -q "<Version>$VERSION</Version>" windows/OtterBlink.csproj
sed -i "s/^Version:.*/Version:        $VERSION/" rpm/otter-blink.spec
sed -i "s/^Release:.*/Release:        1%{?dist}/" rpm/otter-blink.spec
grep -q "^Version:        $VERSION\$" rpm/otter-blink.spec
DATE=$(LC_ALL=C date +"%a %b %d %Y")
awk -v d="$DATE" -v e="$EMAIL" -v v="$VERSION" -v m="$MSG" '{print} /^%changelog/{print "* " d " MicahOttah <" e "> - " v "-1"; print "- " m; print ""}' rpm/otter-blink.spec > rpm/otter-blink.spec.new
mv rpm/otter-blink.spec.new rpm/otter-blink.spec
if [ -d "$HOME/plasmoids/$APPLET_ID" ]; then
  cp files/home/plasmoid/metadata.json "$HOME/plasmoids/$APPLET_ID/metadata.json"
fi

echo "== commit and tag"
git add -A
git commit -q -m "Release v$VERSION: $MSG"
git tag -a "v$VERSION" -m "Otter Blink $VERSION"

echo "== build Linux packages"
mkdir -p "$HOME/rpmbuild/SOURCES"
git archive --format=tar.gz --prefix="otter-blink-$VERSION/" -o "$HOME/rpmbuild/SOURCES/otter-blink-$VERSION.tar.gz" "v$VERSION"
if ! rpmbuild -ba rpm/otter-blink.spec > /tmp/otter-blink-rpmbuild.log 2>&1; then
  tail -30 /tmp/otter-blink-rpmbuild.log
  exit 1
fi

OUT="$HOME/release-files/otter-blink/$VERSION"
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$HOME/rpmbuild/RPMS/noarch/otter-blink-$VERSION-1."*.noarch.rpm "$HOME/rpmbuild/SRPMS/otter-blink-$VERSION-1."*.src.rpm "$HOME/rpmbuild/SOURCES/otter-blink-$VERSION.tar.gz" "$OUT/"

echo "== build Windows zip"
rm -rf windows/bin windows/obj
if ! (cd windows && dotnet build -c Release -v normal) > /tmp/otter-blink-dotnet.log 2>&1; then
  tail -30 /tmp/otter-blink-dotnet.log
  exit 1
fi
WINZIP="otter-blink-windows-$VERSION.zip"
(cd windows/bin/Release && zip -v "$OUT/$WINZIP" OtterBlink.exe OtterBlink.exe.config)

(cd "$OUT" && sha256sum -- * > SHA256SUMS && cat SHA256SUMS)
RPMFILE=$(basename "$OUT"/*.noarch.rpm)

NOTES=$(mktemp)
cat > "$NOTES" << NOTES_EOF
$MSG

Linux, install from the tarball:

    tar xzf otter-blink-$VERSION.tar.gz
    cd otter-blink-$VERSION
    bash install.sh
    bash verify.sh

Linux, or install the RPM (remove any copy installed with install.sh first):

    sudo dnf install ./$RPMFILE

Windows 7 through 11: download $WINZIP, extract both files into one folder, and run OtterBlink.exe. Nothing else to install. The exe is unsigned, so SmartScreen will ask for confirmation.

Check downloads with: sha256sum -c SHA256SUMS
NOTES_EOF

echo
git log --oneline -3
read -r -p "Push to GitHub and create a DRAFT release? [y/N] " ans
[ "$ans" = "y" ] || exit 1

git push origin main
git push origin "v$VERSION"
FINISHED=1

gh release create "v$VERSION" "$OUT"/* -R "$REPO" --title "Otter Blink $VERSION" -F "$NOTES" --draft
echo
echo "Draft created. Review and publish it at https://github.com/$REPO/releases"
