import { config } from 'dotenv';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
config({ path: join(raiz, '.env') });

export const uri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017';
export const nombreDb = process.env.MONGO_DB || 'juegosMesa';
export const apiPort = Number(process.env.API_PORT || 27080);
export const apiHost = process.env.API_HOST || '0.0.0.0';
export const jwtSecret = process.env.JWT_SECRET || 'cambiá-esta-clave-local';
export const jwtDias = process.env.JWT_DIAS || '30';

export const smtpHost = process.env.SMTP_HOST || '';
export const smtpPort = Number(process.env.SMTP_PORT || 587);
export const smtpUser = process.env.SMTP_USER || '';
export const smtpPass = process.env.SMTP_PASS || '';
export const mailFrom =
  process.env.MAIL_FROM || smtpUser || 'Juegos de mesa Argentos <noreply@localhost>';
