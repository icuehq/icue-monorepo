import { setGlobalOptions } from 'firebase-functions/v2';

// index.ts imports this before any module that defines a function: options apply
// only to functions created after this runs.
setGlobalOptions({ region: 'asia-south1' });
