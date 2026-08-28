import { config } from 'dotenv';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
config({ path: join(raiz, '.env') });

export const uri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017';
export const nombreDb = process.env.MONGO_DB || 'juegosMesa';
export const apiPort = Number(process.env.PORT || process.env.API_PORT || 27080);
export const apiHost = process.env.API_HOST || '0.0.0.0';
export const jwtSecret = process.env.JWT_SECRET || 'cambiá-esta-clave-local';
export const jwtDias = process.env.JWT_DIAS || '30';

export const resendApiKey = process.env.RESEND_API_KEY || '';
export const mailFrom =
  process.env.MAIL_FROM ||
  'Juegos de mesa Argentos <onboarding@resend.dev>';

/** Client IDs de Google OAuth (web / Android / iOS), separados por coma. */
export const googleClientIds = String(process.env.GOOGLE_CLIENT_IDS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

/** Test local: cofres sin cooldown (COFRES_SIEMPRE_LISTOS=1). */
export const cofresSiempreListos = process.env.COFRES_SIEMPRE_LISTOS === '1';
