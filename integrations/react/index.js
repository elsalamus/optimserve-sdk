import {useEffect, useRef, useState} from 'react';
export function useOptimServe(hls, {site, key, stream, streamId, onStatus, onError}) {
  const callbacks = useRef({onStatus,onError}); callbacks.current = {onStatus,onError};
  const [stats,setStats] = useState(null);
  useEffect(() => {
    if (!hls) return;
    let disposed = false, delivery, timer, unbind;
    (async () => {
      try {
        const {attach} = await import(/* webpackIgnore: true */ 'https://p2p.optimserve.agency/sdk/optimserve-p2p-module-0.12.0.js');
        if (disposed) return;
        const controller = await attach(hls,{site,key,stream,streamId});
        if (disposed) {await controller.destroy(); return;}
        delivery = controller;
        unbind = delivery.on('status', event => callbacks.current.onStatus?.(event));
        setStats(delivery.snapshot());
        timer = setInterval(() => setStats(delivery.snapshot()),1000);
      } catch (error) {if (!disposed) callbacks.current.onError?.(error);}
    })();
    return () => {disposed = true; clearInterval(timer); unbind?.(); void delivery?.destroy();};
  },[hls,site,key,stream,streamId]);
  return stats;
}
