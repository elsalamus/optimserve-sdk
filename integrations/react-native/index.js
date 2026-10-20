import {NativeModules, NativeEventEmitter, AppState} from 'react-native';
import {openSession} from './lib/session.js';
const native = NativeModules.OptimServe;
const adapter = {
  call(method, ...args) {
    if (!native) throw new Error('Install the OptimServe native package, install iOS pods and rebuild the app. Expo Go cannot load native modules.');
    return native[method](...args);
  },
  subscribe(callback) {
    const emitter = new NativeEventEmitter(native), event = emitter.addListener('OptimServeEvent', callback);
    const state = AppState.addEventListener('change', value => {void native.setBackground(value !== 'active').catch(() => {});});
    void native.setBackground(AppState.currentState !== 'active').catch(() => {});
    return () => {event.remove(); state.remove();};
  }
};
export const createSession = options => openSession(adapter, options);
