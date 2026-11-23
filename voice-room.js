// Supabase Realtime + WebRTC voice rooms. No separate MQTT broker is required.
export class VoiceRoom {
  constructor({supabase,roomId,userId,username,onStatus,onPeer,onRemoteStream}) {
    if(!supabase) throw new Error("Supabase client is required for voice signaling.");
    Object.assign(this,{supabase,roomId,userId,username:username||"User"});
    this.onStatus=onStatus||(()=>{});this.onPeer=onPeer||(()=>{});this.onRemoteStream=onRemoteStream||(()=>{});
    this.peers=new Map();this.channel=null;this.localStream=null;this.joined=false;
  }
  async join() {
    if(!window.isSecureContext&&location.hostname!=="localhost")throw new Error("Voice calls require HTTPS.");
    if(!navigator.mediaDevices?.getUserMedia)throw new Error("This browser does not support microphone access.");
    this.onStatus("Requesting microphone permission…");
    this.localStream=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:true},video:false});
    this.channel=this.supabase.channel("discord-voice-"+this.roomId,{config:{broadcast:{self:false}}});
    this.channel.on("broadcast",{event:"signal"},({payload})=>this.handleSignal(payload).catch(e=>this.onStatus("Voice error: "+e.message)));
    await new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>reject(new Error("Voice signaling timed out. Check Supabase Realtime.")),12000);
      this.channel.subscribe(status=>{
        if(status==="SUBSCRIBED"){clearTimeout(timer);resolve();}
        else if(status==="CHANNEL_ERROR"||status==="TIMED_OUT"){clearTimeout(timer);reject(new Error("Could not join the Supabase voice room."));}
      });
    });
    this.joined=true;
    await this.send({type:"join",from:this.userId,username:this.username});
    this.onStatus("Voice room connected. Waiting for others…");
  }
  async send(payload) {
    if(!this.channel||!this.joined)return;
    const status=await this.channel.send({type:"broadcast",event:"signal",payload});
    if(status!=="ok")this.onStatus("Voice signaling warning: "+status);
  }
  async makePeer(id,name,initiator) {
    if(this.peers.has(id))return this.peers.get(id);
    const pc=new RTCPeerConnection({iceServers:[{urls:"stun:stun.l.google.com:19302"},{urls:"stun:stun1.l.google.com:19302"}]});
    const peer={pc,username:name||"User",pendingCandidates:[]};this.peers.set(id,peer);
    this.localStream.getTracks().forEach(track=>pc.addTrack(track,this.localStream));
    pc.onicecandidate=e=>{if(e.candidate)this.send({type:"candidate",from:this.userId,to:id,candidate:e.candidate}).catch(err=>this.onStatus(err.message));};
    pc.ontrack=e=>{const stream=e.streams?.[0];if(stream)this.onRemoteStream(id,peer.username,stream);};
    pc.onconnectionstatechange=()=>{
      const state=pc.connectionState;
      if(state==="connected")this.onStatus("Voice connected.");
      if(state==="failed"||state==="closed"){this.onPeer(id,null);this.peers.delete(id);}
      else if(state==="disconnected")this.onStatus("A voice connection was interrupted.");
    };
    this.onPeer(id,peer);
    if(initiator){const offer=await pc.createOffer();await pc.setLocalDescription(offer);await this.send({type:"offer",from:this.userId,to:id,username:this.username,sdp:pc.localDescription});}
    return peer;
  }
  async flushCandidates(peer) {
    if(!peer.pc.remoteDescription)return;
    for(const candidate of peer.pendingCandidates.splice(0)){try{await peer.pc.addIceCandidate(candidate);}catch(e){console.warn("ICE candidate rejected",e);}}
  }
  async handleSignal(msg) {
    if(!msg||msg.from===this.userId||(msg.to&&msg.to!==this.userId))return;
    if(msg.type==="join"){await this.makePeer(msg.from,msg.username,true);return;}
    if(msg.type==="leave"){const p=this.peers.get(msg.from);p?.pc.close();this.peers.delete(msg.from);this.onPeer(msg.from,null);return;}
    if(msg.type==="offer"){
      const peer=await this.makePeer(msg.from,msg.username,false);
      await peer.pc.setRemoteDescription(msg.sdp);await this.flushCandidates(peer);
      const answer=await peer.pc.createAnswer();await peer.pc.setLocalDescription(answer);
      await this.send({type:"answer",from:this.userId,to:msg.from,username:this.username,sdp:peer.pc.localDescription});return;
    }
    const peer=this.peers.get(msg.from);if(!peer)return;
    if(msg.type==="answer"){await peer.pc.setRemoteDescription(msg.sdp);await this.flushCandidates(peer);}
    else if(msg.type==="candidate"&&msg.candidate){
      if(peer.pc.remoteDescription){try{await peer.pc.addIceCandidate(msg.candidate);}catch(e){console.warn("ICE candidate rejected",e);}}
      else peer.pendingCandidates.push(msg.candidate);
    }
  }
  async leave() {
    if(this.joined){try{await this.send({type:"leave",from:this.userId,username:this.username});}catch{}}
    this.joined=false;
    for(const [id,p] of this.peers){p.pc.close();this.onPeer(id,null);}this.peers.clear();
    this.localStream?.getTracks().forEach(t=>t.stop());this.localStream=null;
    if(this.channel){await this.supabase.removeChannel(this.channel);this.channel=null;}
    this.onStatus("Not in a voice room.");
  }
}
