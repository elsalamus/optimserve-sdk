export async function attach(hls, options) {
  if (!globalThis.optimserve?.authorize) throw new Error('Install the OptimServe preload bridge.');
  const {attach} = await import(/* webpackIgnore: true */ 'https://p2p.optimserve.agency/sdk/optimserve-p2p-module-0.13.0.js');
  return attach(hls, {...options, authorize:input => globalThis.optimserve.authorize(input)});
}
