import { setGlobalOptions } from 'firebase-functions/v2';

// Imported first by every file that defines a function: options apply only to
// functions created after this runs, so setting them in index.ts is too late.
setGlobalOptions({ region: 'asia-south1' });
