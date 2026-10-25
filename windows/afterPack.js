const fs = require('fs'); const path = require('path'); const ResEdit = require('resedit');
exports.default = async function (ctx) {
  const exePath = path.join(ctx.appOutDir, ctx.packager.appInfo.productFilename + '.exe');
  const exe = ResEdit.NtExecutable.from(fs.readFileSync(exePath));
  const res = ResEdit.NtExecutableResource.from(exe);
  const ico = ResEdit.Data.IconFile.from(fs.readFileSync(path.join(__dirname, 'icons', 'icon.ico')));
  const grp = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries);
  const g = grp[0] || { id: 1, lang: 1033 };
  ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, g.id, g.lang, ico.icons.map(i => i.data));
  const vi = ResEdit.Resource.VersionInfo.fromEntries(res.entries)[0];
  if (vi) {
    const lang = { lang: 1033, codepage: 1200 };
    vi.setStringValues(lang, { ProductName: 'Jääkiekon Pistepörssi', FileDescription: 'Jääkiekon Pistepörssi', CompanyName: 'Teukka', LegalCopyright: '', OriginalFilename: ctx.packager.appInfo.productFilename + '.exe', InternalName: 'JaakiekonPistepörssi' });
    vi.outputToResourceEntries(res.entries);
  }
  res.outputResource(exe);
  fs.writeFileSync(exePath, Buffer.from(exe.generate()));
  console.log('  • exe icon + version info patched');
};
