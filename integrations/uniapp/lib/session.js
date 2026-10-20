const owners = new WeakSet();
const decode = value => typeof value === 'string' ? JSON.parse(value) : value;
export async function openSession(adapter, {appKey, appName, appId, onEvent = () => {}}) {
  if (!/^opa_[a-f\d]{32}_[a-f\d]{64}$/i.test(appKey || '') || typeof appName !== 'string' || !appName.trim() || appName.length > 80 || !/^[A-Za-z\d._-]{1,160}$/.test(appId || '') || typeof onEvent !== 'function') throw new TypeError('Copy your App Key, app name and package/bundle App ID from OptimServe.');
  if (owners.has(adapter)) throw new Error('Close the other OptimServe session first.');
  owners.add(adapter);
  let closed = false, unsubscribe = () => {};
  const call = async (name, ...args) => {
    if (closed) throw new Error('OptimServe session is closed.');
    return decode(await adapter.call(name, ...args));
  };
  try {
    await adapter.call('configure', appKey, appName, appId);
    unsubscribe = adapter.subscribe(raw => {
      if (closed) return;
      try {
        const event = decode(raw);
        if (!event || !['url','stats'].includes(event.type)) return;
        onEvent(event.type === 'url' ? {...(event.playback || event), type:'url'} : event);
      } catch { /* Customer callbacks cannot interrupt policy checks or accounting. */ }
    });
  } catch (error) {try {await adapter.call('close');} catch {} finally {owners.delete(adapter);} throw error;}
  return Object.freeze({
    async prepare(stream, streamId) {
      const url = new URL(stream);
      if (url.protocol !== 'https:' || !url.hostname || url.username || url.password || url.hash || stream.length > 2048 || streamId !== undefined && !/^[A-Za-z\d][A-Za-z\d_.:-]{0,127}$/.test(streamId)) throw new TypeError('Use an HTTPS media URL and a valid optional Stream ID.');
      return call('prepare', stream, streamId ?? null);
    },
    updatePlayback(state, bufferedMs = 0, positionMs = 0) {
      if (!['playing','paused','buffering','stopped'].includes(state) || [bufferedMs,positionMs].some(value => !Number.isFinite(value) || value < 0 || value > Number.MAX_SAFE_INTEGER)) throw new TypeError('Provide a valid playback state and non-negative millisecond positions.');
      return call('updatePlayback', state, bufferedMs, positionMs);
    },
    setBackground(value) {if (typeof value !== 'boolean') throw new TypeError('Provide a background boolean.'); return call('setBackground', value);},
    snapshot: () => call('snapshot'), stop: () => call('stop'),
    async close() {if (closed) return; closed = true; try {try {unsubscribe();} finally {await adapter.call('close');}} finally {owners.delete(adapter);}}
  });
}
