let installPrompt;
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  installPrompt = event;
});
window.addEventListener('appinstalled', () => { installPrompt = undefined; });
window.shopInstall = async () => {
  if (window.matchMedia('(display-mode: standalone)').matches || navigator.standalone) return 'installed';
  if (!installPrompt) return 'manual';
  const prompt = installPrompt;
  installPrompt = undefined;
  await prompt.prompt();
  return (await prompt.userChoice).outcome;
};

async function prepareAppShell() {
  if (!('serviceWorker' in navigator) || !window.isSecureContext) return;
  const response = await fetch('/shop-pwa-version.json', {cache: 'no-store'});
  if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) return;
  const version = await response.json();
  if (!version.release || !Array.isArray(version.assets)) return;
  await navigator.serviceWorker.register('/shop-sw.js', {scope: '/', updateViaCache: 'none'});
  await navigator.serviceWorker.ready;
  if (!navigator.serviceWorker.controller) {
    await new Promise((resolve) => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once: true}));
  }
}

Promise.race([
  prepareAppShell().catch(() => {}),
  new Promise((resolve) => setTimeout(resolve, 3500)),
]).then(() => {
  const script = document.createElement('script');
  script.src = 'flutter_bootstrap.js';
  document.body.append(script);
});