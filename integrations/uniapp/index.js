import {openSession} from './lib/session.js';
let plugin;
const adapter = {
  call(method, ...args) {
    plugin ||= uni.requireNativePlugin('OptimServe-Native');
    if (!plugin) return Promise.reject(new Error('Build the OptimServe native plugin into your app.'));
    return new Promise((resolve,reject) => plugin.call({method,args}, result => result?.error ? reject(new Error(result.error)) : resolve(result?.value)));
  },
  subscribe(callback) {
    plugin.subscribe({},callback);
    const hide = () => {void adapter.call('setBackground',true).catch(()=>{});}, show = () => {void adapter.call('setBackground',false).catch(()=>{});};
    if (uni.onAppHide && uni.offAppHide) uni.onAppHide(hide);
    if (uni.onAppShow && uni.offAppShow) uni.onAppShow(show);
    return () => {plugin.unsubscribe({});uni.offAppHide?.(hide);uni.offAppShow?.(show);};
  }
};
export const createSession = options => openSession(adapter,options);
