import { setGlobalOptions } from 'firebase-functions/v2';

// index.ts imports this before any module that defines a function: options apply
// only to functions created after this runs. `maxInstances` caps spend if a trigger loops
// or a client retries in a storm; each instance serves 80 requests at once (the default).
setGlobalOptions({ region: 'asia-south1', memory: '256MiB', maxInstances: 10 });
