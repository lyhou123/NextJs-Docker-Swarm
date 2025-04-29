import fs from 'fs';

export function readSecret(secretName:string) {
  try {
    return fs.readFileSync(`/run/secrets/${secretName}`, 'utf8').trim();
  } catch (error) {
    console.error(`Error reading secret ${secretName}:`, error);
    return null;
  }
}
