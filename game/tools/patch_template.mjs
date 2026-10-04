import * as ResEdit from "resedit";
import * as PE from "pe-library";
import { readFileSync, writeFileSync } from "node:fs";
const [src, ico, out] = process.argv.slice(2);
const exe = PE.NtExecutable.from(readFileSync(src), { ignoreCert: true });
const res = PE.NtExecutableResource.from(exe);
const iconFile = ResEdit.Data.IconFile.from(readFileSync(ico));
const groups = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries);
const gid = groups.length ? groups[0].id : 1, lang = groups.length ? groups[0].lang : 1033;
ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, gid, lang, iconFile.icons.map((i) => i.data));
const vi = ResEdit.Resource.VersionInfo.fromEntries(res.entries);
const v = vi.length ? vi[0] : ResEdit.Resource.VersionInfo.createEmpty();
v.setFileVersion(1, 0, 0, 0, 1033); v.setProductVersion(1, 0, 0, 0, 1033);
v.setStringValues({ lang: 1033, codepage: 1200 }, {
  FileDescription: "Keyboard Seller Simulator", ProductName: "Keyboard Seller Simulator", CompanyName: "KSS Team",
  LegalCopyright: "© 2026", OriginalFilename: "KeyboardSellerSimulator.exe", InternalName: "KeyboardSellerSimulator",
  FileVersion: "1.0.0.0", ProductVersion: "1.0.0.0" });
v.outputToResourceEntries(res.entries);
res.outputResource(exe);
writeFileSync(out, Buffer.from(exe.generate()));
console.log("patched", out, "icon group", gid);
