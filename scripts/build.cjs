// Both whale plugins build from the same validated artwork, without app.asar.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { readWhalePath } = require('../../dsh-pet/scripts/whale-artwork.cjs');

const pkgDir = path.dirname(__dirname);
const whalePath = readWhalePath();
const ps1Path = path.join(pkgDir, 'whale.ps1');
const source = fs.readFileSync(ps1Path, 'utf8');
const assignment = /^\$whalePathData = '[^']*'\r?$/gm;
if ((source.match(assignment) || []).length !== 1) {
  throw new Error('Expected exactly one whalePathData assignment in whale.ps1');
}
let ps1 = source.replace(assignment, () => "$whalePathData = '" + whalePath + "'");
// PowerShell 5.1 needs a BOM to decode the Chinese menu labels as UTF-8.
if (!ps1.startsWith('\ufeff')) ps1 = '\ufeff' + ps1;
if (ps1 !== source) fs.writeFileSync(ps1Path, ps1, 'utf8');

const icon =
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 23.16 17.04">' +
  '<defs><linearGradient id="g" x1="11.58" y1="0.5" x2="11.58" y2="16.5" gradientUnits="userSpaceOnUse">' +
  '<stop offset="0" stop-color="#5B7CFF"/><stop offset="1" stop-color="#3D5AFE"/>' +
  '</linearGradient></defs><path d="' + whalePath + '" fill="url(#g)"/></svg>\n';
if (!fs.existsSync(path.join(pkgDir, 'icon.svg')) ||
    fs.readFileSync(path.join(pkgDir, 'icon.svg'), 'utf8') !== icon) {
  fs.writeFileSync(path.join(pkgDir, 'icon.svg'), icon, 'utf8');
}
console.log('Applied shared official whale artwork (' + whalePath.length + ' chars)');
