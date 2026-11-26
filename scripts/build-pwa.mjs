import { createHash } from 'node:crypto';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const root = process.argv[2] ?? 'build/web';
const fixed = ['index.html', 'flutter.js', 'flutter_bootstrap.js', 'main.dart.js', 'shop-pwa.js', 'manifest.json'];
async function tree(path) {
  const items = await readdir(join(root, path), {withFileTypes: true});
  const subtrees = await Promise.all(items.map((entry) => {
    const name = path + '/' + entry.name;
    return entry.isDirectory() ? tree(name) : [name];
  }));
  return subtrees.flat();
}
const assets = [...fixed, ...await tree('assets'), ...await tree('canvaskit'), ...await tree('icons')].sort();
const worker = await readFile('web/shop-sw.js', 'utf8');
const hash = createHash('sha256').update(worker);
for (const asset of assets) {
  hash.update(asset).update(await readFile(join(root, asset)));
}
const release = hash.digest('hex').slice(0, 20);
await writeFile(join(root, 'shop-sw.js'), worker.replace('__SHOP_RELEASE__', release));
await writeFile(join(root, 'shop-pwa-version.json'), JSON.stringify({
  release, assets: assets.map((asset) => '/' + asset),
}));
console.log('PWA release ' + release + ' includes ' + assets.length + ' shell files.');
