export type Playback = {url:string; mode:'p2p'|'http'; reason:string};
export type Stats = {http_kib:number|null; peer_kib:number; upload_kib:number; play_ms:number; buffer_ms:number; peers:number; mode:string; reason:string; reporting:boolean};
export type DeliveryEvent = ({type:'url'} & Playback) | {type:'stats'; stats:Stats};
export interface Session {
  prepare(stream:string, streamId?:string):Promise<Playback>;
  updatePlayback(state:'playing'|'paused'|'buffering'|'stopped', bufferedMs?:number, positionMs?:number):Promise<void>;
  setBackground(value:boolean):Promise<void>;
  snapshot():Promise<Stats>; stop():Promise<void>; close():Promise<void>;
}
export function createSession(options:{appKey:string; appName:string; appId:string; onEvent?:(event:DeliveryEvent)=>void}):Promise<Session>;
