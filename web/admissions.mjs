// Retries await the original durable admission, including its failure.
export class Admissions {
  constructor(journal){this.journal=journal;this.pending=new Map();}
  async admit(key,hash,create){
    if(!key)return create();
    const wait=async pending=>{
      if(pending.hash!==hash)throw new Error('Request key reused with different content');
      const result=await pending.promise;
      if(!result.ok)throw new Error(result.error);
      return {...result.record,reused:true};
    };
    if(this.pending.has(key))return wait(this.pending.get(key));
    const prior=await this.journal.find(key);
    if(this.pending.has(key))return wait(this.pending.get(key));
    if(prior){if(prior.hash!==hash)throw new Error('Request key reused with different content');return {...prior,reused:true};}
    let settle;
    const promise=new Promise(resolve=>{settle=resolve;});
    this.pending.set(key,{hash,promise});
    try{const result=await create();settle({ok:true,record:{id:result.id,hash}});return result;}
    catch(error){settle({ok:false,error:error.message});throw error;}
    finally{this.pending.delete(key);}
  }
}
